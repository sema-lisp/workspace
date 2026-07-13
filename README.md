<div align="center">

<img src="https://sema-lang.com/logo.svg" alt="Sema" height="64">

# Sema workspace

**One working directory for the [`sema-lisp`](https://github.com/sema-lisp) ecosystem.**

[![Website](https://img.shields.io/badge/website-sema--lang.com-c8a855)](https://sema-lang.com)
[![Task runner](https://img.shields.io/badge/tasks-Jake-c8a855)](https://jakefile.dev)

</div>

Build, test, and manage the Sema language, shared libraries, package registry,
grammar, and editor integrations from one directory.

Each member is a normal, independent Git clone—not a submodule. This repository
tracks only the shared tooling: `Jakefile`, `repos.tsv`, `scripts/`, and workspace
configuration. Commit and push changes from inside the member repository that
owns them.

## Requirements

- [Git](https://git-scm.com) with SSH access to GitHub
- [Jake](https://jakefile.dev) task runner
- Bash
- A [Rust toolchain](https://rustup.rs) with `cargo`

The bootstrap script installs `sccache` and `cargo-sweep` if they are missing.
It uses Homebrew for `sccache` when available and otherwise installs both tools
with `cargo`.

## Setup

```sh
git clone git@github.com:sema-lisp/workspace.git sema
cd sema
./scripts/ws.sh bootstrap     # clone every repo listed in repos.tsv
cp .env.example .env          # optional: add API keys for LLM recipes
jake -l                       # list workspace and member recipes
```

The main `sema` repository exposes unprefixed recipes such as `jake build` and
`jake test`. Other repositories use namespaces such as `ui.test`, `pkg.build`,
and `ts.test`.

## Workspace layout

All member repositories are cloned directly into the workspace root. There is
no `members/` directory.

```text
sema/                     this workspace repository
├── Jakefile              workspace recipes and member imports
├── repos.tsv             member manifest: local directory + GitHub repository
├── scripts/              workspace, worktree, cache, and reporting helpers
├── .cargo/config.toml    shared Rust build-cache configuration
│
├── sema/                 Rust language, VM, CLI, LSP, DAP, and notebook
├── sema-coder/           sema-coder application
├── pkg/                  package registry
├── ui/                   @sema-lang/ui component library
├── tree-sitter-sema/     shared grammar
├── vscode-sema/          VS Code extension
├── zed-sema/             Zed extension
├── intellij-sema/        IntelliJ plugin
├── emacs-sema/           Emacs mode
├── helix-sema/           Helix support
├── sema.nvim/            Neovim plugin
├── sema.vim/             Vim plugin
├── sublime-sema/         Sublime Text package
└── gh-profile/           sema-lisp GitHub organization profile
```

`repos.tsv` is the source of truth for managed members. Other local scratch
directories may exist beside them, but workspace commands ignore those
directories.

## Common commands

| Command | What it does |
| --- | --- |
| `jake bootstrap` | Clone missing members and install workspace build-cache tools |
| `jake status` | Show the branch and short status of every member |
| `jake update-all` | Fast-forward every member on its current branch |
| `jake foreach cmd='git fetch'` | Run a command in every member |
| `jake pin` | Write a `repos.lock` snapshot of member revisions |
| `jake build` / `jake test` | Build or test the main `sema` repository |
| `jake ui.test` / `jake pkg.build` / `jake ts.test` | Run a namespaced member recipe |
| `jake build-all` / `jake test-all` | Build or test the supported member set |

Run `jake -l` for the full grouped list and `jake -s <recipe>` for recipe details.

## Working on a member

Run Git commands inside the member repository. The workspace root does not track
member files.

```sh
cd ui
git switch -c feature/example
# edit, test, commit, and push from here
```

Use the workspace worktree recipes when you need an isolated checkout:

```sh
jake wt-new name=fix-parser member=sema
jake wt-list
jake wt-rm name=fix-parser
```

## Links

- **Website** — [sema-lang.com](https://sema-lang.com)
- **Playground** — [sema.run](https://sema.run)
- **Documentation** — [sema-lang.com/docs](https://sema-lang.com/docs/)
- **Jake** — [jakefile.dev](https://jakefile.dev)
- **Organization** — [github.com/sema-lisp](https://github.com/sema-lisp)
- **Repository** — [sema-lisp/workspace](https://github.com/sema-lisp/workspace)
