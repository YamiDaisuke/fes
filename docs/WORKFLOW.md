# Workflow

How tasks move from plan to merged PR without the owner tracking anything by hand.

## Roles

- **Orchestrator**: the main Claude Code session, started with `/continue`. Reads state, dispatches agents, moves labels, restacks branches, marks PRs ready. Writes no product code.
- **architect** (`.claude/agents/architect.md`): turns a task into an implementation guide and makes the technical decisions. Asks the owner when a decision is theirs.
- **coder** (`.claude/agents/coder.md`): implements the guide, verifies it, opens a draft PR, fixes findings.
- **qa** (`.claude/agents/qa.md`): tests the running feature for defects and regressions.
- **reviewer** (`.claude/agents/reviewer.md`): reviews the PR for correctness, simplicity and readability.
- **Owner**: answers questions, reviews ready PRs, merges.

## Source of truth: GitHub

All state lives on GitHub so work can stop at any moment (usage limits, closed laptop, a different machine) and resume from nothing but the repo. Nothing important lives only in a local file or in a session's memory.

- **One issue per task**, titled `T05 Background layer`, in its milestone, with the task text from `docs/PLAN.md`.
- **Stage labels** on the issue (exactly one at a time): `stage:design`, `stage:code`, `stage:qa`, `stage:review`, `stage:ready`, `stage:human-changes`. An open task issue with no stage label is todo. Plus `needs-input` when blocked on the owner.
- **Every stage leaves a comment** on the issue (design, questions, QA reports) or the PR (review), and every such comment starts with a machine-readable marker on its first line:

  ```
  <!-- stage:qa round:2 result:fail -->
  ```

  `result` is one of `done`, `pass`, `fail`, `question`. The latest marker plus the label is enough to know exactly what happens next.
- **The PR** links its issue (`Closes #N`) and states its base in the body: `Stacked on #M` or `Based on main`.

If the label and the latest marker disagree (a session died between posting and relabeling), trust the marker and fix the label.

## The pipeline

```
todo ─▶ design ─▶ code ─▶ qa ─▶ review ─▶ ready ─▶ (owner merges)
           │        ▲      │       │        │
           ▼        └─fail─┘       │        ▼
      needs-input   ▲──────fail────┘   human-changes ─▶ code (then qa, review again)
```

### 1. Design (architect)

Input: the issue. Reads SPEC, PLAN, decision records and the code the task touches.

Output: an issue comment `<!-- stage:design round:1 result:done -->` with the implementation guide:

- **Goal**: one or two sentences.
- **Decisions**: each choice made, with the alternative considered and why it lost. Anything worth remembering beyond this task also becomes a short decision record in `docs/decisions/` (the coder commits it).
- **Files**: which to add or change.
- **Steps**: in order, small.
- **Checks**: how the coder and QA verify it works, including what to try in the browser.
- **Tests worth writing**: and which tempting ones to skip.
- **Out of scope**.

Usually under a page. If the task turns out too big for one ~300-line PR, the guide splits it into lettered subtasks (`T05a`, `T05b`) and the orchestrator creates their issues.

**Asking the owner**: only for decisions that are a matter of taste, product direction, an irreversible format, or a new dependency. Everything else, decide and record. A question is an issue comment `<!-- stage:design round:1 result:question -->` with numbered questions, each with options and a recommendation, and the issue gets `needs-input`. The owner answers in a comment (from the GitHub app is fine). The orchestrator removes `needs-input` when the owner's reply is newer than the question, and design resumes.

### 2. Code (coder)

Input: the guide (and on later rounds, the open findings).

1. Create the branch from its base (see Stacking), or check it out if it already exists.
2. Implement in small commits. Fixes are new commits, never amends of pushed commits.
3. Verify: build, `swift test`, Playwright, and run the feature in WebKit the way the guide's checks describe.
4. Push. On round 1 open a **draft** PR using the PR template below.
5. Comment on the issue `<!-- stage:code round:N result:done -->`: what was done, how it was verified, anything that deviated from the guide and why.

### 3. QA (qa)

Tests the running app, not the code: builds the branch, runs the feature in WebKit with the iPad profile, follows the guide's checks, tries edge cases, and re-runs earlier milestone checks for regressions (at least the M1 demo cart once it exists).

Output: issue comment `<!-- stage:qa round:N result:pass|fail -->` with findings, each with an id (`QA-1`), severity (`blocker`, `major`, `minor`), steps, expected, actual. `minor` findings don't fail the round; they go to `docs/DEBT.md` or a follow-up issue at the coder's discretion. On fail, back to code with the findings. On round 2+ QA first re-checks every previous finding and marks it fixed or not.

### 4. Review (reviewer)

Reviews the PR diff and the code it touches, using ponytail's review (`/ponytail-review`) plus this repo's rules in `CLAUDE.md`: comments, tests, simplicity, readability for the owner.

Output: a GitHub PR review with inline comments, posted as a plain comment review (a bot account can't request changes on its own PR), then a PR comment `<!-- stage:review round:N result:pass|fail -->` summarizing findings as `must fix`, `should fix`, `nice to have`. Only `must fix` and `should fix` fail the round. On fail, back to code; the coder replies to each inline comment with the fixing commit or a reason. On round 2+ the reviewer checks those replies first.

### 5. Ready (orchestrator)

When QA and review both passed on the latest commit: mark the PR ready for review (see GitHub commands), set `stage:ready`, and post a short summary comment for the owner. If a QA or review fix changed code after QA passed, QA runs again before ready.

### 6. Human changes

When the owner leaves review comments or requests changes on a ready PR, the orchestrator sets `stage:human-changes` and sends the coder to address every comment. Then QA and review run again on the new commits only, and the PR returns to ready. The owner's comments outrank any agent's opinion. When in doubt about what the owner meant, ask instead of guessing.

### Round limits

Three rounds of code↔QA or code↔review per task. On the fourth failure, stop that task: comment with a clear summary of what keeps failing, add `needs-input`, and move on to other work.

## Stacking

Tasks stack so building never waits on the owner's review. Open task PRs form one GitHub native stack (`docs/decisions/005-native-stacked-prs.md`): a single chain from `main` up, where each PR is based on the branch of the PR below it.

- A new task's base is the branch of the top PR in the stack, or `main` when nothing is unmerged. Its dependencies are then always below it. When the coder opens the draft PR, the orchestrator adds it to the top of the stack (see GitHub commands). With no stack yet, the first two PRs create one.
- **Stack cap: 5 unmerged PRs.** When reached, only work that doesn't add to the stack continues (questions, fixes, human changes). Then stop and report.
- The owner merges from the stack: merging a PR merges every unmerged PR below it, and GitHub retargets the layers above. A layer can't land in a parent branch that already merged.
- Owner setting: "Automatically delete head branches" on. Cloud sessions can't delete branches, and nothing needs a merged branch.

### After a merge

Check before every stage, not only at the start of a run: `gh api 'repos/{owner}/{repo}/pulls?state=closed&sort=updated&direction=desc&per_page=10'`. For each merged PR:

1. Read the stack (`stacks?pull_request=<next PR>`). The lowest open layer should now be based on `main`.
2. If the owner squash-merged, the open layers still carry the merged commits. Rebase the lowest open layer past them, using the merged PR's head SHA (`pulls/<merged>` → `head.sha`), since its branch may be deleted:

   ```
   git fetch origin
   git rebase --onto origin/main <merged-head-sha> <lowest-open-branch>
   git push --force-with-lease origin <lowest-open-branch>
   ```

   Then rebase each layer above onto the one below, as in the next section.
3. Close the merged task's issue if GitHub didn't, and remove its stage label.

Conflicts during a restack go to the coder with the conflict as the task.

### Restack after a fix lower in the stack

When a branch in the middle of the stack gets new commits, rebase each descendant onto its parent, bottom up: `git rebase <parent-branch> <child-branch>`, then push with `--force-with-lease`. This works cleanly because fixes are new commits, never rewritten history.

## PR template

```
Closes #N · Stacked on #M (or: Based on main)

## What
One paragraph.

## Read in this order
1. path/to/core/file.swift — the heart of the change
2. ...

## Concepts
Short explanation of any domain idea a reader needs (e.g. how scanline sprite limits work). Skip if none.

## Try it
Preview: <link posted by CI>. Steps to see it work.

## Tests
What is tested and why those tests matter.

## Deferred
Anything left out on purpose (also in docs/DEBT.md). "None" if none.
```

## Bootstrap (first `/continue` on a fresh repo)

1. Check tools: `git`, `gh` authenticated with repo scope, Swift 6.4 with the Wasm SDK, Node. If something is missing, run `scripts/setup.sh`; if that fails, report and stop. The project is named FES; the Swift package is `FES`.
2. Create the labels, the milestones M0–M8, and issues for every task in M0–M2.
3. Create an issue `Progress` (the owner can pin it) that the orchestrator appends a one-line entry to after each stage (`T05 qa round 1 pass`). It's the human-readable log, not the source of truth.

## GitHub commands

Claude Code cloud sessions (what runs from the phone) block GitHub's GraphQL API, and most `gh issue` / `gh pr` subcommands use it. Use `gh api` REST calls only. `{owner}/{repo}` is filled in by `gh` inside the repo. Write long bodies to a scratch file and pass them with `-F body=@file.md`.

| Action | Command |
|---|---|
| Read issue / its comments | `gh api repos/{owner}/{repo}/issues/N` · `.../issues/N/comments` |
| List open task issues | `gh api 'repos/{owner}/{repo}/issues?state=open&per_page=100'` |
| Comment on issue or PR | `gh api repos/{owner}/{repo}/issues/N/comments -F body=@c.md` |
| Add / remove label | `gh api repos/{owner}/{repo}/issues/N/labels -f 'labels[]=stage:qa'` · `gh api -X DELETE repos/{owner}/{repo}/issues/N/labels/stage:code` |
| Create label / milestone | `gh api repos/{owner}/{repo}/labels -f name=... -f color=...` · `gh api repos/{owner}/{repo}/milestones -f title=...` |
| Create issue | `gh api repos/{owner}/{repo}/issues -f title=... -F body=@b.md -F milestone=<number> -f 'labels[]=task'` |
| Open draft PR | `gh api repos/{owner}/{repo}/pulls -f title=... -f head=<branch> -f base=<base> -F draft=true -F body=@pr.md` |
| PR, its files and review comments | `gh api repos/{owner}/{repo}/pulls/N` · `.../pulls/N/files` · `.../pulls/N/comments` |
| Change PR base | `gh api -X PATCH repos/{owner}/{repo}/pulls/N -f base=main` |
| Find the stack a PR is in | `gh api 'repos/{owner}/{repo}/stacks?pull_request=N'` (`[]` when none) |
| Create a stack (bottom to top) | `echo '{"pull_requests":[19,20]}' \| gh api -X POST repos/{owner}/{repo}/stacks --input -` |
| Add PRs to the top of a stack | `echo '{"pull_requests":[23]}' \| gh api -X POST repos/{owner}/{repo}/stacks/<number>/add --input -` |
| Post a review | `gh api repos/{owner}/{repo}/pulls/N/reviews --input review.json` (event `COMMENT`) |
| Reply to an inline comment | `gh api repos/{owner}/{repo}/pulls/N/comments/<id>/replies -f body=...` |
| Mark ready for review | `gh api -X POST repos/{owner}/{repo}/pulls/N/ccr/ready_for_review` |
| Review threads / resolve | `gh api repos/{owner}/{repo}/pulls/N/ccr/review_threads` · `gh api -X POST repos/{owner}/{repo}/pulls/N/ccr/comments/<id>/resolve` |

## Unattended runs

When nobody is answering: never wait on a question. Post it, add `needs-input`, and work on anything else unblocked. When nothing is unblocked, stop with a summary.
