---
description: Show where the implementation stands, without changing anything.
---

Read-only. Using `git` and `gh api` REST calls only (`docs/WORKFLOW.md` → GitHub commands), report briefly:

- **Your review queue**: ready PRs, bottom of the stack first, with links and preview URLs.
- **Waiting on you**: issues with `needs-input`, with the question in one line each.
- **In progress**: tasks mid-pipeline with stage and round.
- **The stack**: `main ← #12 ← #13 ← ...` and how close it is to the cap.
- **Next up**: the next task `/continue` would start.
- **Drift**: anything where labels, markers and PRs disagree.

Don't dispatch agents, edit labels, or push.
