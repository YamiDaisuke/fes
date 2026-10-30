---
description: Resume the implementation pipeline from wherever it stopped, as the orchestrator.
---

You are the orchestrator described in `docs/WORKFLOW.md`. Read it and `CLAUDE.md` now. You coordinate; you don't write product code yourself. All state comes from GitHub, never from memory of earlier sessions.

Owner's instructions for this run, if any (for example a point to stop at), take priority over the defaults below: $ARGUMENTS

## 1. Sync

- `git fetch origin --prune`. Make sure the working tree is clean; if a previous session left uncommitted work on a task branch, hand it to the coder to finish or discard, don't drop it silently.
- If the repo has no stage labels yet, run Bootstrap from `docs/WORKFLOW.md` and continue.
- Load state: open task issues with labels and their latest marker comments, open PRs with their bases, recently merged PRs.
- Fix drift: a label that disagrees with the latest marker, a merged PR whose issue is still open, a ready PR missing its label.
- Handle any merges since last time (WORKFLOW → Stacking → After a merge). Repeat this check before every dispatch, not only here.
- Remove `needs-input` from any issue where the owner has replied after the latest question.

## 2. Loop

Repeat until nothing is actionable:

1. Pick the next action in this order:
   1. `stage:human-changes`, or a ready PR with owner comments not yet addressed.
   2. A task mid-pipeline, lowest number first. Finish what's started before starting more.
   3. The next `todo` task whose dependencies allow a base (WORKFLOW → Stacking) while under the stack cap.
   Skip anything with `needs-input`.
2. Check for new merges (WORKFLOW → After a merge). Dispatch the agent for its stage with the Agent tool: `architect`, `coder`, `qa` or `reviewer`. Give it the issue number, PR number, branch, base and round. Agents run one at a time; they share the working tree.
3. When it returns, confirm its marker comment exists on GitHub. If it doesn't, the stage didn't happen: retry once, then stop and report.
4. Move the label according to the result, apply round limits, add a newly opened PR to the top of the stack, mark ready when both QA and review passed on the latest commit, restack descendants after any fix lower in the stack.
5. Append one line to the `Progress` issue.

If an agent asked the owner a question and the owner is here in the session, ask them directly with AskUserQuestion, post their answer on the issue so it's recorded, and continue. Otherwise move on.

## 3. Stop

Stop when nothing is actionable, the stack cap is reached, or the owner interrupts. Finish with a short report:

- PRs ready for the owner's review, bottom of the stack first, with links.
- Questions waiting on the owner, with links.
- What's in progress and what runs next.

Every stage leaves its result on GitHub before the next one starts, so stopping at any point is safe. Running `/continue` again picks up exactly here.
