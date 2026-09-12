#!/usr/bin/env python3
"""
verify_pipeline.py — Automated Pre-Flight Quality Gatekeeper for SiagaKita.

Verifies:
1. OpenAPI contracts in docs/api/
2. Database migration naming sequence and docs/DATABASE_SCHEMA.md synchronization
3. Localization dictionary hygiene for Flutter Mobile and Windows Console
4. Regression unit tests (Go Fiber) and static analysis (Flutter)

Usage:
  python3 scripts/verify_pipeline.py [--fast] [--run-tests] [--skip-tests]
"""

import os
import re
import sys
import argparse
import subprocess


def find_repo_root():
    """Finds repository root by locating the .git directory or VERSION file."""
    curr = os.path.abspath(os.getcwd())
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, ".git")) or os.path.exists(os.path.join(curr, "VERSION")):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(os.getcwd())


def check_openapi_contracts(repo_root):
    """Verifies existence and basic validity of OpenAPI contract files in docs/api/."""
    api_dir = os.path.join(repo_root, "docs", "api")
    print("\n--- 1. OpenAPI Contract Verification ---")
    if not os.path.exists(api_dir):
        print(f"[FAIL] docs/api directory not found at: {api_dir}")
        return False

    yaml_files = [f for f in os.listdir(api_dir) if f.endswith(".yaml") or f.endswith(".yml")]
    if not yaml_files:
        print("[FAIL] No OpenAPI YAML contract files found in docs/api/")
        return False

    all_valid = True
    for yf in sorted(yaml_files):
        path = os.path.join(api_dir, yf)
        size = os.path.getsize(path)
        if size == 0:
            print(f"[FAIL] Empty OpenAPI contract file: {yf}")
            all_valid = False
            continue

        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        if "openapi:" not in content and "swagger:" not in content:
            print(f"[FAIL] Missing 'openapi:' or 'swagger:' specification marker in {yf}")
            all_valid = False
        else:
            print(f"[PASS] Contract verified: docs/api/{yf} ({size} bytes)")

    return all_valid


def check_database_migrations(repo_root):
    """Verifies sequential ordering of SQL migrations and synchronization with docs/DATABASE_SCHEMA.md."""
    print("\n--- 2. Database Migration Sequence & Schema Docs Sync ---")
    mig_dir = os.path.join(repo_root, "backend-go", "migrations")
    schema_doc = os.path.join(repo_root, "docs", "DATABASE_SCHEMA.md")

    if not os.path.exists(mig_dir):
        print(f"[FAIL] Migrations directory not found at: {mig_dir}")
        return False

    if not os.path.exists(schema_doc):
        print(f"[FAIL] Database schema documentation not found at: {schema_doc}")
        return False

    sql_files = [f for f in os.listdir(mig_dir) if f.endswith(".sql")]
    if not sql_files:
        print("[FAIL] No SQL migration files found in backend-go/migrations/")
        return False

    # Check 3-digit zero-padded naming convention: NNN_description.(up|down).sql
    migration_pattern = re.compile(r"^(\d{3})_([a-zA-Z0-9_-]+)\.(up|down)\.sql$")
    migrations_by_num = {}
    has_naming_errors = False

    for sf in sql_files:
        match = migration_pattern.match(sf)
        if not match:
            print(f"[FAIL] Invalid migration filename format: {sf} (Must be NNN_description.(up|down).sql)")
            has_naming_errors = True
        else:
            num = int(match.group(1))
            direction = match.group(3)
            if num not in migrations_by_num:
                migrations_by_num[num] = {"up": None, "down": None, "desc": match.group(2)}
            migrations_by_num[num][direction] = sf

    if has_naming_errors:
        return False

    # Verify that each migration has both .up.sql and .down.sql
    has_pair_errors = False
    for num, pair in sorted(migrations_by_num.items()):
        if not pair["up"]:
            print(f"[FAIL] Migration {num:03d} is missing an .up.sql file")
            has_pair_errors = True
        if not pair["down"]:
            print(f"[FAIL] Migration {num:03d} is missing a .down.sql file")
            has_pair_errors = True

    if has_pair_errors:
        return False

    sorted_nums = sorted(migrations_by_num.keys())

    # Verify continuity from 1 to N
    expected_sequence = list(range(1, len(sorted_nums) + 1))
    if sorted_nums != expected_sequence:
        print(f"[FAIL] Migration sequence gap detected! Found: {sorted_nums}, Expected: {expected_sequence}")
        return False

    latest_num = sorted_nums[-1]
    latest_file = migrations_by_num[latest_num]["up"]
    print(f"[PASS] Sequential migration pairs verified: {len(sorted_nums)} migrations (001 to {latest_num:03d})")

    # Verify latest migration is documented in docs/DATABASE_SCHEMA.md
    with open(schema_doc, "r", encoding="utf-8") as f:
        schema_content = f.read()

    latest_str = f"{latest_num:03d}"
    if latest_str not in schema_content:
        print(f"[FAIL] Latest migration {latest_file} ({latest_str}) is not referenced in docs/DATABASE_SCHEMA.md")
        return False

    print(f"[PASS] docs/DATABASE_SCHEMA.md is in sync with latest migration {latest_file}")
    return True


def check_localization_hygiene(repo_root):
    """Executes localization orphan check on both Flutter Mobile and Windows Console."""
    print("\n--- 3. Localization Dictionary Hygiene Audit ---")
    script_path = os.path.join(repo_root, "scripts", "check_localization_orphans.py")

    if not os.path.exists(script_path):
        print(f"[FAIL] check_localization_orphans.py not found at: {script_path}")
        return False

    res = subprocess.run([sys.executable, script_path, "--all"], capture_output=True, text=True)
    sys.stdout.write(res.stdout)
    if res.stderr:
        sys.stderr.write(res.stderr)

    if res.returncode != 0:
        print("[FAIL] Localization dictionary hygiene audit failed.")
        return False

    print("[PASS] Both Mobile and Desktop localization dictionaries are clean and free of orphaned keys.")
    return True


def run_code_tests_and_analysis(repo_root):
    """Runs backend Go tests and Flutter static analysis across mobile and desktop console."""
    print("\n--- 4. Code Quality & Regression Test Suite ---")
    all_passed = True

    # 4.1 Go Backend Tests
    backend_dir = os.path.join(repo_root, "backend-go")
    if os.path.exists(backend_dir) and os.path.exists(os.path.join(backend_dir, "go.mod")):
        print("\n[INFO] Running Go backend tests with race detector (cd backend-go && go test ./...)...")
        go_res = subprocess.run(["go", "test", "./...", "-race", "-timeout", "60s"], cwd=backend_dir)
        if go_res.returncode != 0:
            print("[FAIL] Go backend unit tests failed.")
            all_passed = False
        else:
            print("[PASS] Go backend unit tests passed.")

    # 4.2 Flutter Mobile Analysis
    mobile_dir = os.path.join(repo_root, "mobile-flutter")
    if os.path.exists(mobile_dir) and os.path.exists(os.path.join(mobile_dir, "pubspec.yaml")):
        print("\n[INFO] Running Flutter Mobile static analysis (flutter analyze --fatal-infos)...")
        mob_res = subprocess.run(["flutter", "analyze", "--fatal-infos"], cwd=mobile_dir)
        if mob_res.returncode != 0:
            print("[FAIL] Flutter Mobile static analysis failed.")
            all_passed = False
        else:
            print("[PASS] Flutter Mobile static analysis passed with 0 issues.")

    # 4.3 Flutter Desktop Console Analysis
    desktop_dir = os.path.join(repo_root, "windows_console_flutter")
    if os.path.exists(desktop_dir) and os.path.exists(os.path.join(desktop_dir, "pubspec.yaml")):
        print("\n[INFO] Running Flutter Desktop Console static analysis (flutter analyze --fatal-infos)...")
        desk_res = subprocess.run(["flutter", "analyze", "--fatal-infos"], cwd=desktop_dir)
        if desk_res.returncode != 0:
            print("[FAIL] Flutter Desktop Console static analysis failed.")
            all_passed = False
        else:
            print("[PASS] Flutter Desktop Console static analysis passed with 0 issues.")

    # 4.4 Flutter Responder Mobile Analysis
    responder_dir = os.path.join(repo_root, "mobile-flutter-responder")
    if os.path.exists(responder_dir) and os.path.exists(os.path.join(responder_dir, "pubspec.yaml")):
        print("\n[INFO] Running Flutter Responder static analysis (flutter analyze --fatal-infos)...")
        resp_res = subprocess.run(["flutter", "analyze", "--fatal-infos"], cwd=responder_dir)
        if resp_res.returncode != 0:
            print("[FAIL] Flutter Responder static analysis failed.")
            all_passed = False
        else:
            print("[PASS] Flutter Responder static analysis passed with 0 issues.")

    return all_passed


def check_backlog_planning_sync(repo_root):
    """Executes backlog and planning synchronization check."""
    print("\n--- 5. Backlog & Planning Documentation Parity Audit ---")
    script_path = os.path.join(repo_root, "scripts", "sync_backlog_status.py")
    if not os.path.exists(script_path):
        print(f"[FAIL] sync_backlog_status.py not found at: {script_path}")
        return False

    res = subprocess.run([sys.executable, script_path, "--check"], capture_output=True, text=True)
    sys.stdout.write(res.stdout)
    if res.stderr:
        sys.stderr.write(res.stderr)

    if res.returncode != 0:
        print("[FAIL] Backlog and planning documentation drift detected.")
        return False

    print("[PASS] All planning catalogs, task checklists, and feature logs are in sync with GitHub.")
    return True


def main():
    parser = argparse.ArgumentParser(description="Automated Pre-Flight Quality Gatekeeper for SiagaKita.")
    parser.add_argument("--fast", action="store_true", help="Skip running unit tests and analyzer (audits contracts and migrations only)")
    parser.add_argument("--run-tests", action="store_true", default=True, help="Run full backend unit tests and Flutter static analysis (default)")
    parser.add_argument("--skip-tests", action="store_true", help="Explicitly skip test suite execution")
    args = parser.parse_args()

    repo_root = find_repo_root()
    print("=======================================================")
    print("      SiagaKita Automated Pre-Flight Quality Gate      ")
    print(f"      Repository Root: {repo_root}")
    print("=======================================================")

    results = []

    # 1. OpenAPI Contracts
    results.append(("OpenAPI Contracts", check_openapi_contracts(repo_root)))

    # 2. Database Migrations
    results.append(("Database Migrations", check_database_migrations(repo_root)))

    # 3. Localization Hygiene
    results.append(("Localization Hygiene", check_localization_hygiene(repo_root)))

    # 4. Code Quality & Tests
    if args.fast or args.skip_tests:
        print("\n--- 4. Code Quality & Regression Test Suite ---")
        print("[SKIP] Test execution skipped due to --fast / --skip-tests flag.")
        results.append(("Regression Tests", True))
    else:
        results.append(("Regression Tests", run_code_tests_and_analysis(repo_root)))

    # 5. Backlog & Planning Sync
    results.append(("Backlog & Planning Sync", check_backlog_planning_sync(repo_root)))

    print("\n=======================================================")
    print("                   Summary Scorecard                   ")
    print("=======================================================")
    overall_pass = True
    for name, passed in results:
        status_str = "[PASS]" if passed else "[FAIL]"
        print(f"  {status_str} {name}")
        if not passed:
            overall_pass = False

    print("=======================================================")
    if overall_pass:
        print("[SUCCESS] All pre-flight quality checks passed cleanly.")
        sys.exit(0)
    else:
        print("[ERROR] One or more quality checks failed. Resolve issues before proceeding.")
        sys.exit(1)


if __name__ == "__main__":
    main()
