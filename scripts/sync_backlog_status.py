#!/usr/bin/env python3
"""
scripts/sync_backlog_status.py — Backlog & Planning Synchronization Auditor for SiagaKita.

Audits and synchronizes consistency between:
1. .planning/README.md catalog table status vs PR/issue completion
2. Individual .planning/NN-*.md checklists (- [ ] vs - [x])
3. docs/backlog/features/F-*.md feature logs
4. Live GitHub issues and pull requests

Usage:
  python3 scripts/sync_backlog_status.py --check   # Audit consistency (exits 1 on drift)
  python3 scripts/sync_backlog_status.py --fix     # Automatically repair documentation drift
"""

import argparse
import json
import os
import re
import subprocess
import sys


def run_cmd(cmd):
    """Executes a shell command and returns (returncode, stdout, stderr)."""
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


def find_repo_root():
    """Finds repository root by locating .git or VERSION."""
    curr = os.path.abspath(os.getcwd())
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, ".git")) or os.path.exists(os.path.join(curr, "VERSION")):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(os.getcwd())


def get_repository():
    """Resolves repository name."""
    repo = os.environ.get("REPO")
    if repo:
        return repo
    code, out, _ = run_cmd("gh repo view --json nameWithOwner -q .nameWithOwner")
    if code == 0 and out.strip():
        return out.strip()
    return "fadhlur-alaudin86/SiagaKita"


def fetch_github_state(repo):
    """Fetches all issues and merged PRs in a single batch to avoid multiple CLI calls."""
    print(f"[INFO] Querying GitHub issues and PRs for {repo}...")
    issues_by_num = {}
    prs_by_num = {}

    code_i, out_i, _ = run_cmd(f'gh issue list --repo "{repo}" --state all --limit 150 --json number,state,title,labels')
    if code_i == 0 and out_i:
        try:
            for item in json.loads(out_i):
                issues_by_num[item["number"]] = {
                    "state": item.get("state", ""),
                    "title": item.get("title", ""),
                    "labels": [lbl["name"] for lbl in item.get("labels", []) if "name" in lbl]
                }
        except Exception as e:
            print(f"[WARN] Failed to parse issues JSON: {e}")

    code_p, out_p, _ = run_cmd(f'gh pr list --repo "{repo}" --state all --limit 150 --json number,state,title,mergedAt')
    if code_p == 0 and out_p:
        try:
            for item in json.loads(out_p):
                prs_by_num[item["number"]] = {
                    "state": item.get("state", ""),
                    "title": item.get("title", ""),
                    "merged": bool(item.get("mergedAt"))
                }
        except Exception as e:
            print(f"[WARN] Failed to parse PRs JSON: {e}")

    return issues_by_num, prs_by_num


def audit_planning_catalog(repo_root, issues_map, prs_map, fix_mode=False):
    """Audits .planning/README.md catalog table and individual plan files."""
    readme_path = os.path.join(repo_root, ".planning", "README.md")
    if not os.path.exists(readme_path):
        print(f"[FAIL] .planning/README.md not found at: {readme_path}")
        return False, []

    with open(readme_path, "r", encoding="utf-8") as f:
        readme_content = f.read()

    # Table regex matching: | **NN** | [`NN-name.md`](...) | Target Issues | Parent | Stack | Status | Objective |
    row_pattern = re.compile(
        r'\|\s*\*\*(\d+)\*\*\s*\|\s*\[`([^`]+)`\]\([^)]+\)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|'
    )

    discrepancies = []
    updated_readme = readme_content

    for match in row_pattern.finditer(readme_content):
        full_row = match.group(0)
        plan_num = match.group(1)
        plan_doc = match.group(2)
        target_issues_str = match.group(3).strip()
        parent_str = match.group(4).strip()
        stack_str = match.group(5).strip()
        status_str = match.group(6).strip()
        objective_str = match.group(7).strip()

        target_issue_nums = [int(n) for n in re.findall(r'#(\d+)', target_issues_str)]

        # Determine if all target issues are closed on GitHub
        all_targets_closed = bool(target_issue_nums) and all(
            issues_map.get(n, {}).get("state") == "CLOSED" for n in target_issue_nums
        )

        plan_file_path = os.path.join(repo_root, ".planning", plan_doc)
        has_plan_file = os.path.exists(plan_file_path)

        # Check for status drift: target issues closed but status is still Backlog
        if all_targets_closed and "Merged" not in status_str:
            discrepancies.append({
                "type": "catalog_status_drift",
                "plan": plan_num,
                "doc": plan_doc,
                "detail": f"Target issues {target_issues_str} are CLOSED, but catalog status is '{status_str}'",
                "fixable": True
            })

            if fix_mode:
                # Resolve PR reference from plan file or git
                resolved_pr = ""
                if has_plan_file:
                    with open(plan_file_path, "r", encoding="utf-8") as pf:
                        p_content = pf.read()
                        pr_match = re.search(r'PR\s*#(\d+)', p_content, re.IGNORECASE)
                        if pr_match:
                            resolved_pr = f" (`PR #{pr_match.group(1)}`)"

                new_status = f"Merged{resolved_pr}"
                new_row = f"| **{plan_num}** | [`{plan_doc}`](./{plan_doc}) | {target_issues_str} | {parent_str} | {stack_str} | {new_status} | {objective_str} |"
                updated_readme = updated_readme.replace(full_row, new_row)
                print(f"[FIX] Updated Plan {plan_num} status in .planning/README.md -> {new_status}")

        # Check individual plan document checklists
        if has_plan_file:
            with open(plan_file_path, "r", encoding="utf-8") as pf:
                plan_body = pf.read()

            is_plan_merged = "Merged" in status_str or "Merged" in plan_body or all_targets_closed
            unchecked_boxes = re.findall(r'(\*|-)?\s*\[\s*\]', plan_body)

            if is_plan_merged and unchecked_boxes:
                discrepancies.append({
                    "type": "plan_checklist_drift",
                    "plan": plan_num,
                    "doc": plan_doc,
                    "detail": f"Plan {plan_num} is merged/closed, but contains {len(unchecked_boxes)} unchecked checklist item(s) ([ ])",
                    "fixable": True
                })

                if fix_mode:
                    fixed_body = re.sub(r'(\*|-)?\s*\[\s*\]', lambda m: m.group(0).replace('[ ]', '[x]').replace('[]', '[x]'), plan_body)
                    # Update status line if still marked pending
                    fixed_body = re.sub(r'-\s*\*\*Status\*\*:\s*(?!Merged).*', f"- **Status**: Merged | Verified and closed", fixed_body)
                    with open(plan_file_path, "w", encoding="utf-8") as pf:
                        pf.write(fixed_body)
                    print(f"[FIX] Checked all {len(unchecked_boxes)} checkboxes to [x] in .planning/{plan_doc}")

    if fix_mode and updated_readme != readme_content:
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(updated_readme)

    return (len(discrepancies) == 0, discrepancies)


def audit_feature_backlog_logs(repo_root, issues_map, prs_map, fix_mode=False):
    """Audits docs/backlog/features/ markdown files against GitHub issues state."""
    features_dir = os.path.join(repo_root, "docs", "backlog", "features")
    if not os.path.exists(features_dir):
        return True, []

    discrepancies = []
    feature_files = [f for f in os.listdir(features_dir) if f.endswith(".md") and f.startswith("F-")]

    for ff in sorted(feature_files):
        path = os.path.join(features_dir, ff)
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        issue_nums = [int(n) for n in re.findall(r'#(\d+)', content)]
        target_prs = [int(n) for n in re.findall(r'PR\s*#(\d+)', content, re.IGNORECASE)]

        has_merged_pr = any(prs_map.get(pr, {}).get("merged") for pr in target_prs)
        all_issues_closed = bool(issue_nums) and all(issues_map.get(n, {}).get("state") == "CLOSED" for n in issue_nums if n in issues_map)

        is_completed = has_merged_pr or all_issues_closed
        status_match = re.search(r'\|\s*Status\s*\|\s*([^|]+)\|', content, re.IGNORECASE)
        current_status = status_match.group(1).strip() if status_match else ""

        if is_completed and current_status and "Merged" not in current_status and "Done" not in current_status:
            discrepancies.append({
                "type": "feature_log_status_drift",
                "file": ff,
                "detail": f"Target PR/issues are merged/closed, but feature log status is '{current_status}'",
                "fixable": True
            })

            if fix_mode:
                resolved_pr = f"Merged (PR #{target_prs[0]})" if target_prs else "Done"
                new_content = re.sub(
                    r'(\|\s*Status\s*\|\s*)([^|]+)(\|)',
                    rf'\g<1>{resolved_pr} \3',
                    content,
                    flags=re.IGNORECASE
                )
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                print(f"[FIX] Updated status in docs/backlog/features/{ff} -> {resolved_pr}")

    return (len(discrepancies) == 0, discrepancies)


def main():
    parser = argparse.ArgumentParser(description="Backlog & Planning Synchronization Auditor for SiagaKita.")
    parser.add_argument("--check", action="store_true", help="Audit synchronization without modifying files")
    parser.add_argument("--fix", action="store_true", help="Automatically repair synchronization drift in markdown files")
    args = parser.parse_args()

    repo_root = find_repo_root()
    repo = get_repository()

    print("=======================================================")
    print("      SiagaKita Backlog & Planning Synchronization     ")
    print(f"      Repository: {repo}")
    print(f"      Root: {repo_root}")
    print("=======================================================")

    issues_map, prs_map = fetch_github_state(repo)

    fix_mode = args.fix
    planning_ok, plan_discrepancies = audit_planning_catalog(repo_root, issues_map, prs_map, fix_mode=fix_mode)
    backlog_ok, backlog_discrepancies = audit_feature_backlog_logs(repo_root, issues_map, prs_map, fix_mode=fix_mode)

    all_discrepancies = plan_discrepancies + backlog_discrepancies

    print("\n----------------- Audit Scorecard ---------------------")
    if all_discrepancies:
        print(f"[DRIFT DETECTED] Found {len(all_discrepancies)} synchronization issue(s):")
        for d in all_discrepancies:
            target = d.get("plan") or d.get("file") or d.get("doc")
            print(f"  - [{d['type']}] ({target}): {d['detail']}")

        if fix_mode:
            print("\n[SUCCESS] Synchronization drift has been automatically resolved.")
            sys.exit(0)
        else:
            print("\n[ACTION REQUIRED] Run 'python3 scripts/sync_backlog_status.py --fix' to align documentation.")
            sys.exit(1)
    else:
        print("[PASS] All .planning/ catalogs, checklists, and feature logs are 100% in sync with GitHub.")
        sys.exit(0)


if __name__ == "__main__":
    main()
