#!/usr/bin/env python3
"""
prune_orphaned_evidence.py — Scans and prunes orphaned incident evidence directories.

Audits directories in uploads/incidents/evidence/<year>/<month>/<incident_id> against
the PostgreSQL incidents table. Detects and optionally removes orphaned folders where
the incident UUID does not exist in the database.

Usage:
  python3 scripts/prune_orphaned_evidence.py [--execute] [--dir PATH] [--container NAME]
"""

import argparse
import os
import re
import shutil
import subprocess
import sys


UUID_REGEX = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)


def find_repo_root():
    curr = os.path.abspath(os.getcwd())
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, ".git")) or os.path.exists(
            os.path.join(curr, "VERSION")
        ):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(os.getcwd())


def load_env_file(env_path):
    env = {}
    if not os.path.exists(env_path):
        return env
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip("'\"")
    return env


def get_db_incident_ids(repo_root):
    env_dev = load_env_file(os.path.join(repo_root, "infrastructure", ".env.dev"))
    db_user = os.getenv("DB_USER", env_dev.get("DB_USER", "siagakita_admin"))
    db_name = os.getenv("DB_NAME", env_dev.get("DB_NAME", "siagakita"))
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "5433")
    db_password = os.getenv(
        "DB_PASSWORD",
        env_dev.get(
            "DB_PASSWORD",
            "5566de1f136204174a3a34761d44f361e1d6299744e223609c71fe8ca8ac0978",
        ),
    )

    query = "SELECT id FROM incidents;"

    # Method 1: Try local psql with environment variable PGPASSWORD
    env_copy = os.environ.copy()
    env_copy["PGPASSWORD"] = db_password
    try:
        res = subprocess.run(
            [
                "psql",
                "-h",
                db_host,
                "-p",
                db_port,
                "-U",
                db_user,
                "-d",
                db_name,
                "-t",
                "-A",
                "-c",
                query,
            ],
            capture_output=True,
            text=True,
            env=env_copy,
            timeout=5,
        )
        if res.returncode == 0:
            return {
                line.strip()
                for line in res.stdout.strip().splitlines()
                if line.strip()
            }
    except Exception:
        pass

    # Method 2: Try via docker exec into siagakita_postgres
    try:
        res = subprocess.run(
            [
                "docker",
                "exec",
                "-i",
                "siagakita_postgres",
                "psql",
                "-U",
                db_user,
                "-d",
                db_name,
                "-t",
                "-A",
                "-c",
                query,
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if res.returncode == 0:
            return {
                line.strip()
                for line in res.stdout.strip().splitlines()
                if line.strip()
            }
    except Exception:
        pass

    print(
        "[WARN] Unable to connect to PostgreSQL to fetch incident IDs.",
        file=sys.stderr,
    )
    return None


def get_docker_container_dirs(container_name, base_path):
    cmd = ["docker", "exec", "-i", container_name, "find", base_path, "-maxdepth", "3", "-mindepth", "3", "-type", "d"]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if res.returncode != 0:
            return []
        lines = res.stdout.strip().splitlines()
        return [l.strip() for l in lines if l.strip()]
    except Exception:
        return []


def is_docker_available():
    try:
        res = subprocess.run(["docker", "ps", "-q"], capture_output=True, timeout=3)
        return res.returncode == 0
    except Exception:
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Prune orphaned incident evidence directories."
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Permanently delete orphaned directories (default: dry-run).",
    )
    parser.add_argument(
        "--dir",
        type=str,
        default=None,
        help="Local path to uploads/incidents/evidence directory.",
    )
    parser.add_argument(
        "--container",
        type=str,
        default="siagakita_backend",
        help="Docker backend container name (default: siagakita_backend).",
    )
    args = parser.parse_args()

    repo_root = find_repo_root()
    valid_ids = get_db_incident_ids(repo_root)
    if valid_ids is None:
        print("[ERROR] Cannot proceed without database validation.", file=sys.stderr)
        sys.exit(1)

    print(f"[INFO] Successfully retrieved {len(valid_ids)} valid incident IDs from database.")

    mode_docker = False
    evidence_dirs = []

    if args.dir and os.path.exists(args.dir):
        base_dir = os.path.abspath(args.dir)
        for root, dirs, _ in os.walk(base_dir):
            for d in dirs:
                full_path = os.path.join(root, d)
                rel = os.path.relpath(full_path, base_dir)
                parts = rel.split(os.sep)
                if len(parts) == 3 and UUID_REGEX.match(parts[2]):
                    evidence_dirs.append(full_path)
    else:
        # Check local folder backend-go/uploads or uploads
        local_candidates = [
            os.path.join(repo_root, "backend-go", "uploads", "incidents", "evidence"),
            os.path.join(repo_root, "uploads", "incidents", "evidence"),
        ]
        found_local = False
        for c in local_candidates:
            if os.path.exists(c):
                found_local = True
                for root, dirs, _ in os.walk(c):
                    for d in dirs:
                        full_path = os.path.join(root, d)
                        rel = os.path.relpath(full_path, c)
                        parts = rel.split(os.sep)
                        if len(parts) == 3 and UUID_REGEX.match(parts[2]):
                            evidence_dirs.append(full_path)
                break

        if not found_local:
            if is_docker_available():
                docker_dirs = get_docker_container_dirs(args.container, "/app/uploads/incidents/evidence")
                if docker_dirs:
                    mode_docker = True
                    evidence_dirs = docker_dirs

    if not evidence_dirs:
        print("[PASS] No evidence directories found to inspect.")
        sys.exit(0)

    print(f"[INFO] Scanning {len(evidence_dirs)} incident evidence directories...")
    orphans = []

    for path in evidence_dirs:
        incident_id = os.path.basename(path)
        if incident_id not in valid_ids:
            orphans.append((incident_id, path))

    print("=======================================================")
    print("           Evidence Orphan Pruning Scorecard           ")
    print("=======================================================")
    print(f"Total evidence directories scanned : {len(evidence_dirs)}")
    print(f"Valid directories linked to DB     : {len(evidence_dirs) - len(orphans)}")
    print(f"Orphaned directories detected      : {len(orphans)}")
    print("-------------------------------------------------------")

    if not orphans:
        print("[PASS] Storage volume is clean. Zero orphaned evidence directories.")
        sys.exit(0)

    for inc_id, path in orphans:
        action = "DELETED" if args.execute else "DETECTED (DRY-RUN)"
        print(f"[{action}] Orphan ID: {inc_id} -> {path}")

    if args.execute:
        print("\n[INFO] Pruning orphaned directories...")
        for inc_id, path in orphans:
            if mode_docker:
                subprocess.run(
                    ["docker", "exec", "-i", args.container, "rm", "-rf", path],
                    check=True,
                )
            else:
                shutil.rmtree(path, ignore_errors=True)
        print(f"[PASS] Successfully pruned {len(orphans)} orphaned directories.")
    else:
        print("\n[HINT] Run with '--execute' to permanently delete these orphaned directories.")

    sys.exit(0)


if __name__ == "__main__":
    main()
