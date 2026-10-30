# Setup (for the owner)

One-time steps before the first `/continue`. All of these work from an iPhone or iPad.

## Repo settings (github.com in Safari → the repo → Settings)

- **Branches**: add a rule for `main` that requires a pull request. This is the real guard against agents pushing to `main`; the deny rules in `.claude/settings.json` are only a second layer.
- **General → Pull Requests**: allow squash merging, and turn **on** "Automatically delete head branches". Task PRs form a native stack (`docs/decisions/005-native-stacked-prs.md`): merge from the stack, and GitHub retargets the PRs above.
- **Pages**: source "GitHub Actions" (T03 sets up the deploys).

## Claude Code environment

Cloud sessions start from a fresh machine, so the toolchain has to be installed each time a session starts. In Claude Code, edit the environment you use for this repo and set its setup script to:

```
bash scripts/setup.sh
```

It installs Swift 6.4.1 via swiftly, the Swift Wasm SDK, and, once T01 adds `package.json`, the Node dependencies and Playwright's WebKit. If the setup script runs before the repo is cloned in your environment, paste the contents of `scripts/setup.sh` into the field instead.

Ponytail loads automatically: `.claude/settings.json` declares its marketplace and enables the plugin. Check with `/ponytail` in a session; if it's not there, run `/plugin marketplace add DietrichGebert/ponytail` and `/plugin install ponytail@ponytail`.

## Run

```
/continue
```

The first run bootstraps labels, milestones and issues, then starts T01. Re-run `/continue` any time to resume, including after hitting usage limits. `/status` shows where things stand without changing anything. To go slower: `/continue stop after T03`.

## Your part

- **Questions**: issues labeled `needs-input`. Answer in a comment; the GitHub app works.
- **Reviews**: PRs move to "ready for review" only after QA and code review passed. Review bottom of the stack first, try each from its preview link, comment or request changes. Merge from the PR's stack view: merging a PR also merges every unmerged PR below it. The next `/continue` handles your comments and restacks after merges.
- **Progress**: the `Progress` issue has a one-line log of every stage. Pin it for easy access.
