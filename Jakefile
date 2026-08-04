# Sema workspace — one Jakefile to drive every sema-lisp repo from a single dir.
#
# Members are normal independent clones (see repos.tsv), NOT submodules. On a
# fresh clone of this workspace repo, run `./scripts/ws.sh bootstrap` first to
# clone the members, then `jake -l` lists every member's recipes.
#
# Each member with build recipes ships an `@rooted` Jakefile, so the imports
# below resolve their relative paths against the member's own dir.
#
# The mono (`sema`) is imported BARE — it's the primary repo, so its recipes
# stay unprefixed at the workspace root (`jake build`, `jake test`, `jake
# site.dev`, `jake bench.bench`). The other members are namespaced (`ui.test`,
# `pkg.build`, `ts.test`, …). The mono's own namespaces (site/pg/wasm/bench/
# fuzz/release) don't collide with the member aliases.
@import "sema/Jakefile"
@import "sema-coder/Jakefile"       as coder
@import "pkg/Jakefile"              as pkg
@import "ui/Jakefile"               as ui
@import "tree-sitter-sema/Jakefile" as ts
@import "vscode-sema/Jakefile"      as vscode
@import "intellij-sema/Jakefile"    as intellij
@import "opencode-sema/Jakefile"   as opencode
@import "pi-sema/Jakefile"          as pi

# Shared secrets (ANTHROPIC_API_KEY, …) for the mono's LLM/provider recipes.
@dotenv

# ── Workspace management (delegates to scripts/ws.sh over repos.tsv) ──

@group workspace
@desc "Clone any missing member repos"
task bootstrap:
    @needs git
    ./scripts/ws.sh bootstrap

@group workspace
@desc "Fetch + fast-forward every member on its main branch"
task update-all:
    ./scripts/ws.sh update

@group workspace
@desc "Short git status for every member"
task status:
    @needs sema
    ./scripts/status.sema

@group workspace
@desc "Write repos.lock — a dir/repo/SHA snapshot of every member"
task pin:
    ./scripts/ws.sh pin

@group workspace
@desc "Run a command in every member repo: jake foreach cmd='git fetch'"
task foreach cmd="":
    ./scripts/ws.sh foreach {{cmd}}

# ── Worktrees (the ONLY sanctioned way to create/remove them — see CLAUDE.md) ──

@group worktree
@desc "Create a git worktree under .worktrees/: jake wt-new name=fix-x [branch=fix/x] [member=sema]"
task wt-new name="" branch="" member="sema":
    ./scripts/wt.sh new {{name}} branch={{branch}} member={{member}}

@group worktree
@desc "Remove a .worktrees/ worktree (cargo-cleans its target first): jake wt-rm name=fix-x"
task wt-rm name="":
    ./scripts/wt.sh rm {{name}}

@group worktree
@desc "List all worktrees; flag any outside .worktrees/"
task wt-list:
    ./scripts/wt.sh list

# ── Disk hygiene (build-cache sprawl reclaim + report) ──

@group disk
@desc "Reclaim stale Rust artifacts across ALL targets/worktrees: jake sweep [days=3]"
task sweep days="3":
    @needs cargo-sweep "cargo install cargo-sweep"
    ./scripts/disk.sh sweep {{days}}

@group disk
@desc "Preview what jake sweep would reclaim (deletes nothing): jake sweep-preview [days=3]"
task sweep-preview days="3":
    @needs cargo-sweep "cargo install cargo-sweep"
    ./scripts/disk.sh sweep {{days}} dry

@group disk
@desc "Cap EACH target/ at a size, oldest artifacts first: jake sweep-cap [max=10GB]"
task sweep-cap max="10GB":
    @needs cargo-sweep "cargo install cargo-sweep"
    ./scripts/disk.sh cap {{max}}

@group disk
@desc "Preview what jake sweep-cap would reclaim (deletes nothing): jake sweep-cap-preview [max=10GB]"
task sweep-cap-preview max="10GB":
    @needs cargo-sweep "cargo install cargo-sweep"
    ./scripts/disk.sh cap {{max}} dry

@group disk
@desc "Report size of every target/ under the workspace + sccache + free space"
task target-sizes:
    ./scripts/disk.sh sizes

# ── Reporting ──

@group report
@desc "Honest LOC count across the workspace (excludes deps/build/corpora via .clocignore): jake cloc [args='--by-file']"
task cloc args="":
    @needs cloc "brew install --HEAD cloc"
    ./scripts/cloc.sh {{args}}

# ── Aggregate build/test across members that expose the recipe ──

@group all
@desc "Test the members that have a test recipe (sema, pkg, ui, grammar, intellij, pi)"
task test-all: [test, pkg.test, ui.test, ts.test, intellij.test, pi.test]
    echo "workspace: all member tests complete"

@group all
@desc "Build the core buildable members (sema, pkg, ui bundle, grammar, pi)"
task build-all: [build, pkg.build, ui.build, ts.generate, pi.build]
    echo "workspace: core members built"
