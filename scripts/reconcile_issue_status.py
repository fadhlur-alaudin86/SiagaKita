#!/usr/bin/env python3
"""
scripts/reconcile_issue_status.py — Issue Status & Parent Tracker Automation for SiagaKita.

Handles:
1. Transitioning issue status labels: in-progress -> in-review -> ready -> done.
2. Auto-closing sub-issues upon PR merge and auto-completing markdown checklists (- [x]).
3. Auto-updating parent tracking issues: completing checklist boxes and setting status: ready
   when all child sub-issues and PRs are merged (leaving final closure to human review).
4. Reconciling recently merged PRs to bypass GitHub Actions event suppression on auto-merges.

Usage:
  python3 scripts/reconcile_issue_status.py [--reconcile] [--limit 25]
"""

import argparse
import json
import os
import re
import subprocess
import sys


STATUS_LABELS = ["status: in-progress", "status: in-review", "status: ready", "status: done"]


def run_cmd(cmd):
    """Executes a shell command and returns (returncode, stdout, stderr)."""
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


def get_repository():
    """Resolves the current GitHub repository in owner/repo format."""
    repo = os.environ.get("REPO")
    if repo:
        return repo
    code, out, _ = run_cmd("gh repo view --json nameWithOwner -q .nameWithOwner")
    if code == 0 and out.strip():
        return out.strip()
    return "fadhlur-alaudin86/SiagaKita"


def set_issue_assignee(repo, issue_num, assignee):
    """Assigns the specified user to the issue if not already assigned."""
    if not assignee or assignee.endswith("[bot]"):
        return
    code, out, _ = run_cmd(f'gh issue view "{issue_num}" --repo "{repo}" --json assignees -q ".assignees[].login"')
    if code == 0:
        existing = set(out.splitlines())
        if assignee not in existing:
            print(f"Assigning issue #{issue_num} to @{assignee}")
            run_cmd(f'gh issue edit "{issue_num}" --repo "{repo}" --add-assignee "{assignee}"')


def set_issue_status(repo, issue_num, target_status):
    """Ensures an issue only has the target status label by removing any other status labels."""
    code, out, _ = run_cmd(f'gh issue view "{issue_num}" --repo "{repo}" --json labels -q ".labels[].name"')
    if code != 0:
        print(f"Failed to fetch labels for issue #{issue_num}")
        return
    existing_labels = set(out.splitlines())
    to_remove = [lbl for lbl in existing_labels if lbl in STATUS_LABELS and lbl != target_status]

    cmd = f'gh issue edit "{issue_num}" --repo "{repo}"'
    if target_status not in existing_labels:
        cmd += f' --add-label "{target_status}"'
    for lbl in to_remove:
        cmd += f' --remove-label "{lbl}"'
    if target_status not in existing_labels or to_remove:
        print(f"Transitioning issue #{issue_num} to {target_status} (removing: {to_remove})")
        run_cmd(cmd)


def autocomplete_checklist(repo, issue_num):
    """Marks all task and acceptance criteria checkboxes to [x] in an issue body."""
    code, out, _ = run_cmd(f'gh issue view "{issue_num}" --repo "{repo}" --json body -q .body')
    if code != 0 or not out:
        return False
    body = out
    updated_body = re.sub(r'(\*|-)?\s*\[\s*\]', lambda m: m.group(0).replace('[ ]', '[x]').replace('[]', '[x]'), body)
    if updated_body != body:
        print(f"Updating checklist items to [x] for issue #{issue_num}")
        p = subprocess.Popen(['gh', 'issue', 'edit', str(issue_num), '--repo', repo, '--body', updated_body], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        p.communicate()
        return True
    return False


def autocomplete_and_close(repo, issue_num, reason="completed"):
    """Marks checkboxes [x], sets label status: done, and closes issue if open."""
    code, out, _ = run_cmd(f'gh issue view "{issue_num}" --repo "{repo}" --json state,stateReason')
    if code != 0:
        print(f"Issue #{issue_num} not found, skipping.")
        return
    data = json.loads(out)
    state = data.get("state", "")
    state_reason = data.get("stateReason", "")

    # Always set status: done
    set_issue_status(repo, issue_num, "status: done")

    if state_reason == "NOT_PLANNED":
        print(f"Issue #{issue_num} closed as not planned, skipping checklist completion.")
        return

    autocomplete_checklist(repo, issue_num)

    if state == "OPEN":
        print(f"Closing issue #{issue_num} with reason: {reason}")
        run_cmd(f'gh issue close "{issue_num}" --repo "{repo}" --reason {reason}')


def extract_issues(text, pr_num=None):
    """Extracts closing issues and parent tracking issues from text."""
    parent_clause_pattern = re.compile(
        r'(?mi)^[ \t-]*(?:parent(?:\s+issues?)?|refs?|related\s+to)\s*:\s*(#\d+(?:[\s,]+(?:and\s+)?#\d+)*)'
    )
    parent_issues = set()
    for match in parent_clause_pattern.finditer(text):
        clause = match.group(1)
        parent_issues.update(re.findall(r'#(\d+)', clause))

    closing_clause_pattern = re.compile(
        r'(?:close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+(?:sub-?issues?|sub-?tasks?|issues?|tasks?|bugs?)?\s*:?\s*(#\d+(?:[\s,]+(?:and\s+)?#\d+)*)',
        re.IGNORECASE
    )
    closing_issues = set()
    for match in closing_clause_pattern.finditer(text):
        clause = match.group(1)
        closing_issues.update(re.findall(r'#(\d+)', clause))

    standalone_colon_pattern = re.compile(
        r'(?:close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved):?\s*(#\d+(?:[\s,]+(?:and\s+)?#\d+)*)',
        re.IGNORECASE
    )
    for match in standalone_colon_pattern.finditer(text):
        clause = match.group(1)
        closing_issues.update(re.findall(r'#(\d+)', clause))

    closing_issues = closing_issues - parent_issues
    if pr_num:
        closing_issues.discard(str(pr_num))
        parent_issues.discard(str(pr_num))
    return closing_issues, parent_issues


def find_repo_root():
    """Finds repository root by locating .git or VERSION."""
    curr = os.path.abspath(os.getcwd())
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, ".git")) or os.path.exists(os.path.join(curr, "VERSION")):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(os.getcwd())


def get_parent_sub_issues(repo, parent_num, repo_root=None):
    """
    Resolves all child sub-issues for a given parent tracking issue.
    Queries:
    1. .planning/README.md catalog mapping (Parent -> Target Issues)
    2. GitHub issue search for child issues declaring 'Parent Issue: #{parent_num}'
    3. Direct references in parent issue body
    """
    sub_issues = set()
    if not repo_root:
        repo_root = find_repo_root()

    # 1. Check .planning/README.md catalog table
    readme_path = os.path.join(repo_root, ".planning", "README.md")
    if os.path.exists(readme_path):
        try:
            with open(readme_path, "r", encoding="utf-8") as f:
                content = f.read()
            row_pattern = re.compile(
                r'\|\s*\*\*\d+\*\*\s*\|\s*\[`[^`]+`\]\([^)]+\)\s*\|\s*([^|]+)\|\s*([^|]+)\|'
            )
            for m in row_pattern.finditer(content):
                target_str = m.group(1)
                parent_str = m.group(2)
                p_match = re.search(r'#(\d+)', parent_str)
                if p_match and int(p_match.group(1)) == int(parent_num):
                    for t_num in re.findall(r'#(\d+)', target_str):
                        sub_issues.add(str(t_num))
        except Exception as e:
            print(f"[WARN] Failed to parse .planning/README.md for parent #{parent_num}: {e}")

    # 2. Search GitHub for issues declaring 'Parent Issue: #{parent_num}'
    code, out, _ = run_cmd(
        f'gh issue list --repo "{repo}" --state all --search "Parent Issue: #{parent_num}" --json number -q ".[].number"'
    )
    if code == 0 and out.strip():
        for line in out.splitlines():
            if line.strip():
                sub_issues.add(line.strip())

    # 3. Check parent issue body itself for explicit child issue listings
    code_p, out_p, _ = run_cmd(f'gh issue view "{parent_num}" --repo "{repo}" --json body -q .body')
    if code_p == 0 and out_p.strip():
        for num in re.findall(r'#(\d+)', out_p):
            if str(num) != str(parent_num):
                sub_issues.add(str(num))

    sub_issues.discard(str(parent_num))
    return sub_issues


def inspect_and_update_parent_issue(repo, parent_num, pr_num=None, pr_title=""):
    """
    Evaluates a parent issue. If all referenced sub-issues are closed:
    - Auto-completes checklist boxes to [x].
    - Transitions status label to status: ready.
    - Posts an informational summary comment.
    Does NOT auto-close the issue, allowing tech lead verification.
    """
    code, out, _ = run_cmd(f'gh issue view "{parent_num}" --repo "{repo}" --json state,body,labels')
    if code != 0 or not out:
        return
    try:
        data = json.loads(out)
    except Exception:
        return

    state = data.get("state", "")
    labels = [lbl.get("name") for lbl in data.get("labels", []) if isinstance(lbl, dict)]

    referenced_sub_issues = get_parent_sub_issues(repo, parent_num)
    if pr_num:
        referenced_sub_issues.discard(str(pr_num))

    if not referenced_sub_issues:
        print(f"Parent issue #{parent_num}: No child sub-issues found or mapped. Skipping automation.")
        return

    print(f"Parent issue #{parent_num}: Evaluating child sub-issues: {sorted(referenced_sub_issues, key=int)}")
    all_subs_closed = True
    for sub in referenced_sub_issues:
        code_sub, out_sub, _ = run_cmd(f'gh issue view "{sub}" --repo "{repo}" --json state -q .state')
        if code_sub == 0 and out_sub.strip() == "OPEN":
            print(f"Parent issue #{parent_num}: Sub-issue #{sub} is still OPEN.")
            all_subs_closed = False
            break

    if all_subs_closed:
        print(f"Parent issue #{parent_num}: All sub-issues {referenced_sub_issues} are closed. Completing checklists and transitioning to status: ready.")
        autocomplete_checklist(repo, parent_num)
        if state == "OPEN" and "status: ready" not in labels:
            set_issue_status(repo, parent_num, "status: ready")
            msg = (
                f"**Status Update (Auto-Reconciled):** All child sub-tasks for parent issue #{parent_num} have been merged to `dev`. "
                f"Checklist items have been marked complete (`[x]`) and status updated to `status: ready` for final review."
            )
            run_cmd(f'gh issue comment "{parent_num}" --repo "{repo}" --body "{msg}"')
    else:
        print(f"Parent issue #{parent_num}: One or more child sub-tasks remain open. No status change.")


def reconcile_merged_prs(repo, limit=25):
    """Reconciles open issues and parent issues referenced by merged PRs to dev."""
    print(f"--- Running Reconciliation on last {limit} merged PRs to dev on {repo} ---")
    code, out, err = run_cmd(f'gh pr list --repo "{repo}" --state merged --base dev --limit {limit} --json number,title,body,author,commits')
    if code != 0:
        print(f"Failed to fetch merged PRs: {err}")
        return
    try:
        prs = json.loads(out)
    except Exception as e:
        print(f"Failed to parse PRs JSON: {e}")
        return

    for pr in prs:
        curr_pr_num = pr.get("number")
        curr_pr_title = pr.get("title", "")
        curr_pr_body = pr.get("body", "") or ""
        curr_pr_author = pr.get("author", {}).get("login", "")

        full_text = f"{curr_pr_title}\n{curr_pr_body}"
        for c in pr.get("commits", []):
            full_text += f"\n{c.get('messageHeadline', '')}\n{c.get('messageBody', '')}"

        closing_issues, parent_issues = extract_issues(full_text, curr_pr_num)

        # 1. Reconcile closing issues
        for issue_num in closing_issues:
            code_issue, out_issue, _ = run_cmd(f'gh issue view "{issue_num}" --repo "{repo}" --json state,stateReason,labels')
            if code_issue != 0 or not out_issue:
                continue
            try:
                issue_data = json.loads(out_issue)
            except Exception:
                continue

            state = issue_data.get("state", "")
            state_reason = issue_data.get("stateReason", "")
            labels = [lbl.get("name") for lbl in issue_data.get("labels", []) if isinstance(lbl, dict)]

            if state_reason == "NOT_PLANNED":
                continue

            if state == "OPEN":
                print(f"[Reconciliation] Auto-completing open issue #{issue_num} from merged PR #{curr_pr_num}")
                set_issue_assignee(repo, issue_num, curr_pr_author)
                autocomplete_and_close(repo, issue_num)
                msg = f"**Status Update (Auto-Reconciled):** PR #{curr_pr_num} ({curr_pr_title}) telah dimerge ke `dev`. Seluruh checklist tugas ditandai selesai (`[x]`) dan label diperbarui menjadi `status: done`."
                run_cmd(f'gh issue comment "{issue_num}" --repo "{repo}" --body "{msg}"')
            elif "status: done" not in labels:
                print(f"[Reconciliation] Ensuring status: done for closed issue #{issue_num}")
                set_issue_status(repo, issue_num, "status: done")

        # 2. Reconcile parent tracker issues
        for parent_num in parent_issues:
            inspect_and_update_parent_issue(repo, parent_num, curr_pr_num, curr_pr_title)


def handle_event(repo):
    """Processes GitHub Actions environment event parameters."""
    event_name = os.environ.get("EVENT_NAME", "")
    pr_action = os.environ.get("PR_ACTION", "")
    pr_number = os.environ.get("PR_NUMBER", "")
    pr_title = os.environ.get("PR_TITLE", "")
    pr_body = os.environ.get("PR_BODY", "")
    pr_merged = os.environ.get("PR_MERGED", "") == "true"
    pr_author = os.environ.get("PR_AUTHOR", "")
    review_state = os.environ.get("REVIEW_STATE", "")
    reviewer = os.environ.get("REVIEWER", "")
    issue_action = os.environ.get("ISSUE_ACTION", "")
    event_issue_num = os.environ.get("ISSUE_NUMBER", "")
    issue_label_name = os.environ.get("ISSUE_LABEL_NAME", "")
    sender_login = os.environ.get("SENDER_LOGIN", "")

    print(f"--- Processing Event: {event_name} (Action: {pr_action or issue_action}) ---")

    # 1. Schedule & Workflow Dispatch
    if event_name in ["schedule", "workflow_dispatch"]:
        reconcile_merged_prs(repo, limit=25)
        return

    # 2. Direct Issue Events
    if event_name == "issues" and event_issue_num:
        if issue_action == "closed":
            print(f"Direct issue closure detected for #{event_issue_num}")
            autocomplete_and_close(repo, event_issue_num)
        elif issue_action == "labeled" and issue_label_name == "status: in-progress":
            print(f"Issue #{event_issue_num} marked in-progress by @{sender_login}")
            set_issue_status(repo, event_issue_num, "status: in-progress")
            set_issue_assignee(repo, event_issue_num, sender_login)
        else:
            print(f"Issue event '{issue_action}' with label '{issue_label_name}' ignored.")
        return

    # 3. Pull Request / Push Events
    full_text = ""
    if event_name == "push":
        code, commit_msg, _ = run_cmd("git log -1 --pretty=%B")
        code_sha, commit_sha, _ = run_cmd("git log -1 --pretty=%H")
        full_text = commit_msg
        pr_merged = True

        if commit_sha:
            code_pr, pr_out, _ = run_cmd(f'gh api repos/{repo}/commits/{commit_sha}/pulls --jq ".[0].number"')
            if code_pr == 0 and pr_out.strip() and pr_out.strip() != "null":
                pr_number = pr_out.strip()
                code_data, pr_data, _ = run_cmd(f'gh pr view "{pr_number}" --repo "{repo}" --json title,body')
                if code_data == 0:
                    data = json.loads(pr_data)
                    pr_title = data.get("title", "")
                    pr_body = data.get("body", "")
                    full_text += f"\n{pr_title}\n{pr_body}"
    else:
        full_text = f"{pr_title}\n{pr_body}"

    closing_issues, parent_issues = extract_issues(full_text, pr_number)

    print(f"PR Number: #{pr_number}")
    print(f"Closing issues: {closing_issues}")
    print(f"Parent issues: {parent_issues}")

    # Process closing sub-issues
    for issue_num in closing_issues:
        if issue_num == pr_number:
            continue

        if event_name == "pull_request":
            if pr_action in ["opened", "reopened", "ready_for_review", "synchronize"]:
                set_issue_status(repo, issue_num, "status: in-review")
                set_issue_assignee(repo, issue_num, pr_author)
                if pr_action in ["opened", "ready_for_review"]:
                    run_cmd(f'gh issue comment "{issue_num}" --repo "{repo}" --body "**Status Update:** PR #{pr_number} ({pr_title}) telah diajukan untuk review."')
            elif pr_action == "closed" and pr_merged:
                set_issue_assignee(repo, issue_num, pr_author)
                autocomplete_and_close(repo, issue_num)
                run_cmd(f'gh issue comment "{issue_num}" --repo "{repo}" --body "**Status Update:** PR #{pr_number} telah dimerge ke `dev`. Seluruh checklist tugas ditandai selesai (`[x]`) dan label diperbarui menjadi `status: done`."')

        elif event_name == "pull_request_review" and review_state == "approved":
            set_issue_status(repo, issue_num, "status: ready")
            run_cmd(f'gh issue comment "{issue_num}" --repo "{repo}" --body "**Status Update:** PR #{pr_number} telah diapprove oleh @{reviewer} dan siap dimerge (`status: ready`)."')

        elif event_name == "push":
            autocomplete_and_close(repo, issue_num)
            run_cmd(f'gh issue comment "{issue_num}" --repo "{repo}" --body "**Status Update:** PR #{pr_number or ""} telah dimerge ke `dev`. Seluruh checklist tugas ditandai selesai (`[x]`) dan label diperbarui menjadi `status: done`."')

    # Process parent tracking issues
    for parent_num in parent_issues:
        if parent_num == pr_number:
            continue
        inspect_and_update_parent_issue(repo, parent_num, pr_number, pr_title)

    # Trigger reconciliation on push to catch any bot squash merges
    if event_name == "push":
        reconcile_merged_prs(repo, limit=10)


def main():
    parser = argparse.ArgumentParser(description="Issue Status & Parent Tracker Automation for SiagaKita.")
    parser.add_argument("--reconcile", action="store_true", default=True, help="Reconcile recently merged PRs on dev (default)")
    parser.add_argument("--limit", type=int, default=25, help="Number of merged PRs to inspect during reconciliation")
    args = parser.parse_args()

    repo = get_repository()

    # If running inside GitHub Actions event
    if "EVENT_NAME" in os.environ and os.environ.get("EVENT_NAME"):
        handle_event(repo)
    else:
        reconcile_merged_prs(repo, limit=args.limit)


if __name__ == "__main__":
    main()
