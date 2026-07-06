# Sema workspace

A single working dir that pulls together every [`sema-lisp`](https://github.com/sema-lisp)
repo so you can build, test, and manage the whole project from one spot.

**Members are normal independent clones, not git submodules.** This repo tracks
only the shared tooling — the root `Jakefile`, the `repos.tsv` manifest, and
`scripts/ws.sh`. Each member (`sema`, `ui`, `tree-sitter-sema`, the editor
plugins, …) is a plain checkout on `main` that you commit and push on its own.
No detached-HEAD or submodule-pointer dance.

## Setup

```sh
git clone git@github.com:sema-lisp/workspace.git sema
cd sema
./scripts/ws.sh bootstrap     # clone every member from repos.tsv
cp .env.example .env          # add API keys (optional; for the mono's LLM recipes)
jake -l                       # every member's recipes, namespaced
```

## Layout

```
sema/                 ← this workspace repo
├── Jakefile          composes each member + workspace recipes
├── repos.tsv         member manifest (<dir> <github-repo>)
├── scripts/ws.sh     bootstrap / update / status / foreach / pin
├── sema/             the Rust monorepo (sema-lisp/sema)
├── ui/               @sema-lang/ui component library
├── tree-sitter-sema/ shared grammar
├── vscode-sema/ zed-sema/ intellij-sema/ emacs-sema/ helix-sema/
├── sema.nvim/ sema.vim/ sublime-sema/     editor plugins
└── gh-profile/       the org .github profile repo
```

## Common commands

| Command | What it does |
| --- | --- |
| `jake bootstrap` | Clone any missing members |
| `jake status` | Short git status across every member |
| `jake update-all` | Fast-forward every member on `main` |
| `jake foreach cmd='git fetch'` | Run a command in every member |
| `jake pin` | Write `repos.lock` — a dir/repo/SHA snapshot (reproducible set) |
| `jake test-all` | Test the members that expose a `test` recipe |
| `jake sema.build` · `jake ui.test` · `jake ts.test` | A specific member's recipe |

Run `jake -l` for the full grouped list and `jake -s <recipe>` for details.
