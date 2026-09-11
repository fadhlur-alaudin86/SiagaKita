#!/usr/bin/env python3
"""
check_localization_orphans.py — Detect orphaned translation keys in SiagaKita Flutter dictionaries.

Validates Localization Invariant #5 (GEMINI.md):
"Prune Unused Entries: When deleting or refactoring UI text, immediately prune orphaned
dictionary entries in app_localization.dart. Never leave dead, prototype, or duplicate
keys in the dictionary."

Usage:
  python3 scripts/check_localization_orphans.py [--mobile] [--desktop] [--all]
"""

import os
import re
import sys
import argparse


def find_repo_root():
    """Finds the repository root by locating the .git directory or VERSION file."""
    curr = os.path.abspath(os.getcwd())
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, ".git")) or os.path.exists(os.path.join(curr, "VERSION")):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(os.getcwd())


def extract_dictionary_keys(app_loc_path):
    """Extracts all translation keys from the _idToEn dictionary in app_localization.dart."""
    if not os.path.exists(app_loc_path):
        print(f"Error: File not found: {app_loc_path}", file=sys.stderr)
        return None

    with open(app_loc_path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r"static\s+const\s+Map<String,\s*String>\s+_idToEn\s*=\s*\{(.*?)\};", content, re.DOTALL)
    if not match:
        print(f"Error: Could not locate '_idToEn' map in {app_loc_path}", file=sys.stderr)
        return None

    dict_content = match.group(1)
    keys = re.findall(r"""['"](.*?)['"]\s*:\s*['"]""", dict_content)
    return keys


def scan_for_orphans(app_loc_path, lib_dir):
    """Scans all Dart files in lib_dir (excluding app_localization.dart) to detect unreferenced keys."""
    keys = extract_dictionary_keys(app_loc_path)
    if keys is None:
        return None

    # Aggregate text of all Dart files in lib_dir
    all_dart_text = []
    for root, _, files in os.walk(lib_dir):
        for f in files:
            if f.endswith(".dart") and f != "app_localization.dart":
                full_path = os.path.join(root, f)
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as df:
                        all_dart_text.append(df.read())
                except Exception as e:
                    print(f"Warning: Could not read {full_path}: {e}", file=sys.stderr)

    combined_text = "\n".join(all_dart_text)

    orphaned = [k for k in keys if k not in combined_text]
    return orphaned, len(keys)


def main():
    parser = argparse.ArgumentParser(description="Check for orphaned localization dictionary keys.")
    parser.add_argument("--mobile", action="store_true", help="Check mobile-flutter only")
    parser.add_argument("--responder", action="store_true", help="Check mobile-flutter-responder only")
    parser.add_argument("--desktop", action="store_true", help="Check windows_console_flutter only")
    parser.add_argument("--all", action="store_true", help="Check all flutter clients (default)")

    args = parser.parse_args()

    check_any_specific = args.mobile or args.responder or args.desktop
    check_mobile = args.mobile or args.all or not check_any_specific
    check_responder = args.responder or args.all or not check_any_specific
    check_desktop = args.desktop or args.all or not check_any_specific

    repo_root = find_repo_root()
    has_errors = False

    targets = []
    if check_mobile:
        targets.append({
            "name": "mobile-flutter",
            "loc_file": os.path.join(repo_root, "mobile-flutter", "lib", "core", "localization", "app_localization.dart"),
            "lib_dir": os.path.join(repo_root, "mobile-flutter", "lib"),
        })
    if check_responder and os.path.exists(os.path.join(repo_root, "mobile-flutter-responder")):
        targets.append({
            "name": "mobile-flutter-responder",
            "loc_file": os.path.join(repo_root, "mobile-flutter-responder", "lib", "core", "localization", "app_localization.dart"),
            "lib_dir": os.path.join(repo_root, "mobile-flutter-responder", "lib"),
        })
    if check_desktop:
        targets.append({
            "name": "windows_console_flutter",
            "loc_file": os.path.join(repo_root, "windows_console_flutter", "lib", "core", "localization", "app_localization.dart"),
            "lib_dir": os.path.join(repo_root, "windows_console_flutter", "lib"),
        })

    print("--- Localization Dictionary Hygiene Audit ---")

    for target in targets:
        name = target["name"]
        loc_file = target["loc_file"]
        lib_dir = target["lib_dir"]

        res = scan_for_orphans(loc_file, lib_dir)
        if res is None:
            has_errors = True
            continue

        orphans, total_keys = res
        if orphans:
            has_errors = True
            print(f"\n[FAIL] {name}: Found {len(orphans)} orphaned keys (out of {total_keys} total keys):")
            for o in orphans:
                preview = o.replace("\n", "\\n")
                if len(preview) > 60:
                    preview = preview[:57] + "..."
                print(f"  - '{preview}'")
        else:
            print(f"[PASS] {name}: Clean (0 orphaned keys out of {total_keys} total keys)")

    print("---------------------------------------------")

    if has_errors:
        print("Localization audit failed: Orphaned keys detected or file error occurred.")
        print("Please prune orphaned dictionary entries in app_localization.dart before proceeding.")
        sys.exit(1)
    else:
        print("Localization audit passed: All dictionary entries have active references.")
        sys.exit(0)


if __name__ == "__main__":
    main()
