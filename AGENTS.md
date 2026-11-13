# Agent guide

Project workflows and Ponytail skill guides live in `docs/agents/`.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `naderalexan/cairobible`; use `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The triage skill's five roles map to GitHub labels listed in `docs/agents/triage-labels.md`.

### Ponytail skills

| Skill | Use for | Guide |
| --- | --- | --- |
| `ponytail` | Smallest complete coding changes | [`ponytail.md`](docs/agents/ponytail.md) |
| `ponytail-review` | Review a change | [`ponytail-review.md`](docs/agents/ponytail-review.md) |
| `ponytail-audit` | Audit a repo or named area | [`ponytail-audit.md`](docs/agents/ponytail-audit.md) |
| `ponytail-debt` | List deferred shortcuts | [`ponytail-debt.md`](docs/agents/ponytail-debt.md) |
| `ponytail-gain` | Show the benchmark results | [`ponytail-gain.md`](docs/agents/ponytail-gain.md) |
| `ponytail-help` | Show Ponytail commands and levels | [`ponytail-help.md`](docs/agents/ponytail-help.md) |

## Implementation default

For every implementation, use `/ponytail` in full mode by default and follow [`ponytail.md`](docs/agents/ponytail.md). Honor a user-selected level or request to stop Ponytail.

## Implementation closeout

- After each completed implementation:
    1. Stage only changes from that implementation; preserve unrelated pre-existing worktree changes.
    2. Commit its changes with a concise message. 
    3. Build and run:
        3.1 For webapp changes: rebuild and run the app in a browser to verify that the changes work as expected.
        3.2 For iOS changes: rebuild and run the app in a simulator to verify that the changes work as expected.
    4. Ask the user whether the changes accomplish the intended goal:
        4.1 if yes, ask whether to push the commit. Wait for the user's answer before pushing.
        4.2 if no, ask whether to revert the commit or make further changes
    5. Once a user confirms that the changes accomplish the intended goal, ask whether to push the commit. Wait for the user's answer before pushing.         