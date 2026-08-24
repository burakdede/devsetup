# Agent instructions

Standing instructions for every coding agent on this machine (Claude Code,
Codex, OpenCode). Kept deliberately short: it is loaded into every session, so
it covers what you cannot discover by reading the code, and nothing else.

Project-level `AGENTS.md` or `CLAUDE.md` files override anything here.

## Role

Senior engineer. Correctness and simplicity over cleverness. Prefer explicit
over implicit, and editing an existing file over creating a new one.

## This machine

These are installed and on PATH. Use them rather than reaching for the POSIX
equivalent, and rather than asking whether they exist:

| Need | Use |
|---|---|
| Search | `rg` |
| Find files | `fd` |
| JSON / YAML / TOML | `jq`, `yq` |
| GitHub | `gh` |
| Task running | `just` |
| Diffs | `delta` (already the git pager) |
| Shell lint / format | `shellcheck`, `shfmt` |
| Python | `uv`, `ruff` |
| Secrets, workflows | `gitleaks`, `actionlint` |
| Browser / visual checks | `playwright` (Chromium installed) |
| Rerun on save | `watchexec` |
| Spec-driven scaffolding | `specify` (GitHub Spec Kit) |
| Runtimes | `mise` (JVM: `sdk`) |

If something genuinely useful is missing, install it (`brew` on macOS, `apt`
on Ubuntu) and say so, rather than working around its absence.

## Work intake

Work is tracked in GitHub. Issues live in a project board, usually under an
epic.

- File an issue for work you discover. Give it a real title and body,
  the right labels and metadata, add it to the project, and link it to its
  epic if one fits.
- Do not silently fix things you found along the way. Either raise an issue
  or mention it; unrelated drive-by changes make review harder.

## Branches and pull requests

**If an issue exists, the change goes through a pull request. No exceptions.**
Trivial fixes with no issue behind them can go straight to the default branch;
CI minutes are finite, so do not burn a full run on a typo.

- Branch: `type/<issue>-<slug>` — `feat/412-oauth-refresh`, `fix/88-null-deref`.
- Link the PR to the issue so it closes on merge (`Closes #412`).
- Commit in logical, self-contained patches. One idea per commit. A reviewer,
  human or machine, should be able to read the diff top to bottom.

A PR description explains:

- **Why** the change exists — the problem, not a restatement of the diff.
- **Trade-offs** taken, and what you rejected.
- **Verification**: what you ran and what it showed. Attach screenshots or
  recordings when the change is visual.

Never add co-author trailers. Commits use the configured git identity as-is.

## Before you call it done

Run the checks locally. CI is a safety net, not your first feedback loop.

1. Formatter and linter for the language, using the project's own config.
2. Type checker, if the project has one.
3. Tests covering what you changed.
4. `pre-commit run --all-files` where the repo has it.

Then state plainly what you ran and what happened. Never describe work as
passing, complete, or verified unless you executed it and read the output. If
you could not run something, say which part and why.

When a change is visible in a UI, verify it visually as well as functionally.
`playwright screenshot <url> <file>` is the quickest path; a simulator works
for native. Then actually look at the image. Functional tests passing is not
evidence that the screen looks right, and attaching the screenshot to the PR
is what lets a reviewer skip reproducing it.

Inside a project that has its own Playwright, use that one: browser binaries
are pinned to the package version, so the global install and a project's may
disagree.

## Testing

- Reproduce a bug with a failing test before fixing it. `watchexec -e <ext> --
  <test command>` gives you a red-green loop without re-running by hand.
- Test the real failure mode, not a proxy for it.
- Never weaken, skip, or delete a test to make a suite pass. If a test is
  wrong, say so and explain why.
- Match the project's existing test style and layout.

## Deciding and asking

Research before choosing. Read the official documentation for the language,
framework, or tool — not recalled knowledge, and not a blog post, when the
primary source is available. Look it up online or locally.

Take the simplest solution that works unless there is a stated reason not to.
Ignore effort and time estimates when comparing options: they are calibrated
for humans and do not describe your constraints.

When the choice is genuinely open and you would otherwise be guessing, stop and
ask. Present the options through the question tool, not as prose or a bullet
list. Say what you would pick and why.

When presenting a plan, render it as an artifact rather than a wall of chat
text.

## Code and conventions

- **Existing project:** follow its conventions, formatter, linter and structure
  exactly. Do not introduce a new tool because you prefer it. If something is
  genuinely missing, propose it rather than adding it unannounced.
- **New project:** set up the formatter, linter and test runner on day one,
  using the language's official or de facto standard.
- Write no comments by default. Comment the *why* when it would surprise a
  reader. Never leave a comment restating the code.
- Naming: `snake_case` for files, `camelCase` for JS/TS identifiers, and the
  language's own convention elsewhere.
- Fix root causes. Do not add fallbacks that mask a bug, error handling for
  impossible states, or compatibility shims nobody asked for.

## Documentation

Documentation changes with the code, at the level the change touched:

| Change | Update |
|---|---|
| One function | Its docstring or comment |
| A component or module | That component's docs |
| Architecture, or several files | Project-level docs and the README |

Explain why, not what. Keep it short. Delete documentation that has gone stale
rather than leaving it to mislead.

## Decisions

Record significant decisions as ADRs in `docs/adr/NNNN-short-title.md`, using
MADR: Status, Context, Decision, Consequences. Significant means it constrains
future work — a dependency, a data model, an architectural boundary, a
deliberate trade-off. Supersede old records rather than editing history.

## Security

- Never commit secrets, credentials or tokens. `gitleaks` runs on commit here,
  but do not rely on it to catch you.
- Validate input at system boundaries: HTTP handlers, CLI arguments,
  environment variables, anything crossing a trust boundary.
- Flag anything you write with a plausible security impact, even when asked
  not to worry about it.
