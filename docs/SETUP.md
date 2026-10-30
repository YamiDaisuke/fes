# Setup (for the owner)

One-time steps before the first `/continue`. All of these work from an iPhone or iPad.

## Repo settings (github.com in Safari → the repo → Settings)

- **Branches**: add a rule for `main` that requires a pull request. This is the real guard against agents pushing to `main`; the deny rules in `.claude/settings.json` are only a second layer.
- **General → Pull Requests**: allow squash merging, and turn **off** "Automatically delete head branches". The orchestrator needs merged branches for restacking and deletes them itself.
- **General → Danger Zone → Change visibility**: make the repo public. GitHub Pages on a private repo needs a paid plan; public also makes Actions minutes free. The Pages site is public either way: anyone with the URL can open `main` and every PR preview.
- **Pages**: source "GitHub Actions".
- **Environments → `github-pages` → Deployment branches and tags**: "Selected branches and tags", with a branch rule `*` (keep the `main` rule or remove it; `*` covers it). GitHub creates this environment allowing only `main`, which blocks PR previews. Don't choose "No restriction": an environment without branch rules makes Pages fall back to accepting deployments only from `main` ([deploy-pages security notes](https://github.com/actions/deploy-pages#security-considerations)). The environment appears once Pages is set to GitHub Actions, or after the first deploy attempt. A deploy job that fails with "not allowed to deploy to github-pages due to environment protection rules" or "Invalid deployment branch and no branch protection rules set in the environment" means this rule is missing.

CI needs nothing else: no secrets, and the repo-wide "Workflow permissions" can stay read-only, because each workflow job declares the permissions it needs.

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
- **Reviews**: PRs move to "ready for review" only after QA and code review passed. Review bottom of the stack first, try each from its preview link, comment or request changes, merge when happy. The next `/continue` handles your comments and restacks after merges.
- **Progress**: the `Progress` issue has a one-line log of every stage. Pin it for easy access.
