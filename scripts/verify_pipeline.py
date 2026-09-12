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
import shutil
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


def check_code_formatting(repo_root, fix=False):
    """Verifies gofmt in backend-go and dart format across all Flutter workspaces."""
    print("\n--- 4. Code Formatting Verification (gofmt & dart format) ---")
    all_passed = True

    # 4.1 Go Formatting (gofmt)
    backend_dir = os.path.join(repo_root, "backend-go")
    if os.path.exists(backend_dir):
        if fix:
            print("[INFO] Formatting Go source files (gofmt -w .)...")
            subprocess.run(["gofmt", "-w", "."], cwd=backend_dir)
            print("[PASS] Go formatting applied.")
        else:
            print("[INFO] Checking Go formatting (gofmt -l .)...")
            res = subprocess.run(["gofmt", "-l", "."], cwd=backend_dir, capture_output=True, text=True)
            if res.returncode != 0 or res.stdout.strip():
                print("[FAIL] Unformatted Go files found:")
                for f in res.stdout.strip().splitlines():
                    print(f"  - backend-go/{f}")
                print("[HINT] Run 'gofmt -w backend-go/' or 'python3 scripts/verify_pipeline.py --format' to fix.")
                all_passed = False
            else:
                print("[PASS] All Go source files are properly formatted.")

    # 4.2 Flutter / Dart Formatting
    flutter_apps = [
        ("mobile-flutter", "Flutter Mobile"),
        ("windows_console_flutter", "Flutter Desktop Console"),
        ("mobile-flutter-responder", "Flutter Mobile Responder")
    ]

    for app_dir, label in flutter_apps:
        full_path = os.path.join(repo_root, app_dir)
        if os.path.exists(full_path) and os.path.exists(os.path.join(full_path, "pubspec.yaml")):
            if fix:
                print(f"[INFO] Formatting {label} source files (dart format .)...")
                subprocess.run(["dart", "format", "."], cwd=full_path)
                print(f"[PASS] {label} formatting applied.")
            else:
                print(f"[INFO] Checking {label} formatting (dart format --set-exit-if-changed .)...")
                res = subprocess.run(["dart", "format", "--set-exit-if-changed", "."], cwd=full_path, capture_output=True, text=True)
                if res.returncode != 0:
                    print(f"[FAIL] {label} has unformatted Dart source files.")
                    print(res.stdout.strip())
                    print(f"[HINT] Run 'dart format {app_dir}/' or 'python3 scripts/verify_pipeline.py --format' to fix.")
                    all_passed = False
                else:
                    print(f"[PASS] {label} formatting verified clean.")

    return all_passed


def check_code_linters(repo_root):
    """Runs golangci-lint, go vet, govulncheck, and flutter analyze across all workspaces."""
    print("\n--- 5. Static Analysis, Linters & Security (golangci-lint, govulncheck & flutter analyze) ---")
    all_passed = True

    # 5.1 Go Vet, golangci-lint & govulncheck
    backend_dir = os.path.join(repo_root, "backend-go")
    if os.path.exists(backend_dir) and os.path.exists(os.path.join(backend_dir, "go.mod")):
        print("[INFO] Running go vet in backend-go...")
        res_vet = subprocess.run(["go", "vet", "./..."], cwd=backend_dir)
        if res_vet.returncode != 0:
            print("[FAIL] go vet reported issues.")
            all_passed = False
        else:
            print("[PASS] go vet passed cleanly.")

        print("[INFO] Running golangci-lint in backend-go...")
        res_lint = subprocess.run(["golangci-lint", "run", "--timeout=5m"], cwd=backend_dir)
        if res_lint.returncode != 0:
            print("[FAIL] golangci-lint reported issues.")
            all_passed = False
        else:
            print("[PASS] golangci-lint passed cleanly with 0 issues.")

        print("[INFO] Running govulncheck in backend-go...")
        govulncheck_cmd = None
        if shutil.which("govulncheck"):
            govulncheck_cmd = ["govulncheck", "./..."]
        elif os.path.exists(os.path.expanduser("~/go/bin/govulncheck")):
            govulncheck_cmd = [os.path.expanduser("~/go/bin/govulncheck"), "./..."]
        elif shutil.which("go"):
            govulncheck_cmd = ["go", "run", "golang.org/x/vuln/cmd/govulncheck@latest", "./..."]

        if govulncheck_cmd:
            res_vuln = subprocess.run(govulncheck_cmd, cwd=backend_dir)
            if res_vuln.returncode != 0:
                print("[FAIL] govulncheck reported vulnerability issues.")
                all_passed = False
            else:
                print("[PASS] govulncheck passed cleanly with 0 vulnerabilities.")
        else:
            print("[WARN] Neither govulncheck nor go was found to execute vulnerability checks.")

    # 5.2 Flutter Static Analysis
    flutter_apps = [
        ("mobile-flutter", "Flutter Mobile"),
        ("windows_console_flutter", "Flutter Desktop Console"),
        ("mobile-flutter-responder", "Flutter Mobile Responder")
    ]

    for app_dir, label in flutter_apps:
        full_path = os.path.join(repo_root, app_dir)
        if os.path.exists(full_path) and os.path.exists(os.path.join(full_path, "pubspec.yaml")):
            print(f"[INFO] Running {label} static analysis (flutter analyze --fatal-infos)...")
            res_mob = subprocess.run(["flutter", "analyze", "--fatal-infos"], cwd=full_path)
            if res_mob.returncode != 0:
                print(f"[FAIL] {label} static analysis failed.")
                all_passed = False
            else:
                print(f"[PASS] {label} static analysis passed with 0 issues.")

    return all_passed


def run_regression_tests(repo_root):
    """Runs backend Go tests and Flutter unit tests."""
    print("\n--- 6. Regression Unit Test Suite ---")
    all_passed = True

    backend_dir = os.path.join(repo_root, "backend-go")
    if os.path.exists(backend_dir) and os.path.exists(os.path.join(backend_dir, "go.mod")):
        print("\n[INFO] Running Go backend tests with race detector (cd backend-go && go test ./...)...")
        go_res = subprocess.run(["go", "test", "./...", "-race", "-timeout", "60s"], cwd=backend_dir)
        if go_res.returncode != 0:
            print("[FAIL] Go backend unit tests failed.")
            all_passed = False
        else:
            print("[PASS] Go backend unit tests passed.")

    mobile_dir = os.path.join(repo_root, "mobile-flutter")
    if os.path.exists(mobile_dir) and os.path.exists(os.path.join(mobile_dir, "test")):
        print("\n[INFO] Running Flutter Mobile unit tests (flutter test)...")
        mob_test = subprocess.run(["flutter", "test"], cwd=mobile_dir)
        if mob_test.returncode != 0:
            print("[FAIL] Flutter Mobile unit tests failed.")
            all_passed = False
        else:
            print("[PASS] Flutter Mobile unit tests passed.")

    return all_passed


def check_backlog_planning_sync(repo_root):
    """Executes backlog and planning synchronization check."""
    print("\n--- 7. Backlog & Planning Documentation Parity Audit ---")
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
    parser.add_argument("--fast", action="store_true", help="Skip running unit tests and analyzer (audits contracts, migrations, formatting, and sync)")
    parser.add_argument("--format", action="store_true", help="Automatically format Go (gofmt -w) and Dart (dart format) source files across all workspaces")
    parser.add_argument("--skip-tests", action="store_true", help="Explicitly skip regression test suite execution")
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

    # 4. Code Formatting (gofmt & dart format)
    results.append(("Code Formatting", check_code_formatting(repo_root, fix=args.format)))

    # 5. Static Analysis, Linters & Security (golangci-lint, govulncheck & flutter analyze)
    if args.fast:
        print("\n--- 5. Static Analysis, Linters & Security ---")
        print("[SKIP] Linter, security, and static analysis skipped due to --fast flag.")
        results.append(("Static Analysis & Linters", True))
    else:
        results.append(("Static Analysis & Linters", check_code_linters(repo_root)))

    # 6. Regression Unit Tests
    if args.fast or args.skip_tests:
        print("\n--- 6. Regression Unit Test Suite ---")
        print("[SKIP] Test execution skipped due to --fast / --skip-tests flag.")
        results.append(("Regression Tests", True))
    else:
        results.append(("Regression Tests", run_regression_tests(repo_root)))

    # 7. Backlog & Planning Sync
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
