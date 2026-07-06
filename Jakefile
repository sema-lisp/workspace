# Sema workspace — one Jakefile to drive every sema-lisp repo from a single dir.
#
# Members are normal independent clones (see repos.tsv), NOT submodules. On a
# fresh clone of this workspace repo, run `./scripts/ws.sh bootstrap` first to
# clone the members, then `jake -l` shows every member's recipes namespaced.
#
# Each member with build recipes ships an `@rooted` Jakefile, so the imports
# below resolve their relative paths against the member's own dir.
@import "sema/Jakefile"             as sema
@import "ui/Jakefile"               as ui
@import "tree-sitter-sema/Jakefile" as ts
@import "vscode-sema/Jakefile"      as vscode
@import "intellij-sema/Jakefile"    as intellij

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
    ./scripts/ws.sh status

@group workspace
@desc "Write repos.lock — a dir/repo/SHA snapshot of every member"
task pin:
    ./scripts/ws.sh pin

@group workspace
@desc "Run a command in every member repo: jake foreach cmd='git fetch'"
task foreach:
    ./scripts/ws.sh foreach {{cmd}}

# ── Aggregate build/test across members that expose the recipe ──

@group all
@desc "Test the members that have a test recipe (sema, ui, grammar, intellij)"
task test-all: [sema.test, ui.test, ts.test, intellij.test]
    echo "workspace: all member tests complete"

@group all
@desc "Build the core buildable members (sema, ui bundle, grammar)"
task build-all: [sema.build, ui.build, ts.generate]
    echo "workspace: core members built"
