# Agent guide

Project workflows and Ponytail skill guides live in `docs/agents/`.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `naderalexan/cairobible`; use `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The triage skill's five roles map to GitHub labels listed in `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repo: check the root glossary and relevant ADRs in `docs/adr/`. See `docs/agents/domain.md`.

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

- After each completed implementation, commit its changes with a concise message. Stage only changes from that implementation; preserve unrelated pre-existing worktree changes.
- When the implementation completes a related GitHub issue, ask whether the user wants the issue closed and whether the commit should be pushed. Wait for the user's answer before closing or pushing.
