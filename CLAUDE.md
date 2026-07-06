# CLAUDE.md — Sema workspace

This directory (`sema-lisp/workspace`) is a **meta-repo**: a single working dir
that composes every `sema-lisp` repo so you can drive them from one spot. Read
this before doing anything here.

## The one rule that matters: each subdir is its own repo

Every member directory (`sema/`, `ui/`, `tree-sitter-sema/`, `vscode-sema/`,
`zed-sema/`, `intellij-sema/`, `emacs-sema/`, `helix-sema/`, `sema.nvim/`,
`sema.vim/`, `sublime-sema/`, `gh-profile/`, `pkg/`) is a **separate git repo
with its own remote**. They are independent clones (see `repos.tsv`), **not git
submodules**.

- **Commit and push member changes inside that member**, to its own remote.
  `cd <member> && git add … && git commit && git push`. Never try to commit a
  member's files from the workspace root.
- **This workspace repo tracks ONLY its own tooling** — `Jakefile`, `repos.tsv`,
  `scripts/ws.sh`, `README.md`, `.env.example`, `.gitignore`. Every member dir is
  gitignored (allowlist `.gitignore`). If `git status` at the workspace root ever
  shows a member dir, something is wrong — do **not** `git add -A` here.
- **Follow each member's own `CLAUDE.md` / `AGENTS.md`** when working inside it.
  The Rust monorepo is `sema/` — its `sema/AGENTS.md` is authoritative for all
  crate/CLI/LLM/notebook work and its own git rules.

## Working in the mono vs a plugin

- Rust/CLI/stdlib/LLM/notebook/website/playground/pkg-of-the-mono work → `sema/`
  (`cd sema`, obey `sema/AGENTS.md`).
- A specific editor plugin, the grammar, or the UI library → that member's dir.
- Cross-repo status/build/test → the workspace `Jakefile` (below).

## Jake from the workspace root

`jake -l` lists every member's recipes namespaced (`sema.build`, `ui.test`,
`ts.test`, `intellij.test`, `vscode.package`) plus workspace aggregates. Common:

| Command | Effect |
| --- | --- |
| `jake status` | git status across all members |
| `jake update-all` | fast-forward every member on `main` |
| `jake bootstrap` | clone any missing members (or `./scripts/ws.sh bootstrap`) |
| `jake foreach cmd='git fetch'` | run a command in every member |
| `jake pin` | write `repos.lock` — a dir/repo/SHA snapshot |
| `jake sema.<r>` / `jake ui.<r>` | a specific member's recipe |

The Jakefile `@import`s each member's **`@rooted`** Jakefile, so a missing member
makes `jake` fail to parse until you `bootstrap`.

## Constraints

- **Don't move, rename, or delete member dirs** — it breaks `repos.tsv` and the
  Jakefile `@import`s. To add a member: clone it, add a `repos.tsv` line, and (if
  it has a `@rooted` Jakefile) add an `@import … as <ns>` to the Jakefile.
- **Don't convert members to submodules.** The manifest+clone model is deliberate
  (no detached-HEAD / two-step-commit friction).
- **Secrets live in `.env`** (gitignored, loaded via `@dotenv`). Never commit real
  keys; `.env.example` is the template.
- Non-`sema-lisp` scratch dirs may exist here (e.g. `pkg-packages/`); they're
  gitignored and not workspace members — leave them alone unless asked.
- The `git stash` / `git checkout --` cautions from `sema/AGENTS.md` apply in
  every member: prefer worktrees; never clobber another agent's uncommitted work.
