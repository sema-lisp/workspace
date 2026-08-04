# AGENTS.md — Sema workspace

This directory (`sema-lisp/workspace`) is a **meta-repo**: a single working dir
that composes every `sema-lisp` repo so you can drive them from one spot. Read
this before doing anything here.

## The one rule that matters: each subdir is its own repo

Every member directory (`sema/`, `ui/`, `tree-sitter-sema/`, `vscode-sema/`,
`zed-sema/`, `intellij-sema/`, `emacs-sema/`, `helix-sema/`, `sema.nvim/`,
`sema.vim/`, `sublime-sema/`, `gh-profile/`, `pkg/`, `pkg-packages/`) is a
**separate git repo with its own remote**. They are independent clones (see
`repos.tsv`), **not git submodules**.

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
- **If your cwd is `sema/` (or any mono worktree), you are still inside this
  workspace.** This root `AGENTS.md` and its **Worktrees** + **Disk hygiene**
  rules below are MANDATORY there — obey `sema/AGENTS.md` for crate work *and*
  these rules for worktrees/builds. Create worktrees with `jake wt-new` from the
  workspace root, never `git worktree add` by hand.

## Shipping a language feature across every editor plugin

A new special form, macro, or builtin in the mono is not delivered until every
plugin highlights it **and** each plugin's registry has a release carrying that
change. Merging the plugin PRs is only half the job — most registries ship from
a **git tag**, not from `main`.

### Order of operations

1. **Derive the canonical list of new names from the mono**, not from memory —
   cross-check at least two sources (`crates/sema-eval/src/prelude.rs`,
   the `register()` calls in `crates/sema-stdlib/`, `crates/sema-docs/entries/`,
   `website/.vitepress/sema.tmLanguage.json`). Record both full names and short
   aliases (`workflow/approval` *and* `approval`).
2. **Apply to every plugin** (list below), then check the matrix both ways: a
   canonical name missing from a plugin, and a name a plugin highlights that
   does not exist (a typo ships as a real defect).
3. **Also update indent/keyword classification, not just colours.** A prelude
   macro with one distinguished argument plus a body (`policy/without`) belongs
   in emacs `sema--indent-1-forms` and vim `lispwords`; a plain builtin does
   not. Getting this backwards is the most common mistake here.
4. **Merge each plugin PR** (own repo, own remote, own CI).
5. **Release only the plugins whose registry needs it** — see the table.
6. **Verify the registry actually serves the new version** afterwards; a green
   workflow is not proof a marketplace accepted the upload.

### What each registry needs (verified 2026-08-04)

| Plugin | Publishes when | Users auto-update? | Third-party gate |
| --- | --- | --- | --- |
| `vscode-sema` | push tag `v*` → VS Marketplace **and** Open VSX | **Yes**, default on (~2 h delay) | No |
| `intellij-sema` | push tag `v*` → JetBrains Marketplace | **No** — the IDE only notifies | **Yes — JetBrains reviews every update, not just the first** |
| `sublime-sema` | push a bare semver tag (`0.4.0`) | Yes, channel polled ~hourly | No (channel PR already merged) |
| `emacs-sema` | **push to `main`** — MELPA rebuilds from the default branch | **No** — `M-x package-upgrade-all` is manual | No |
| `zed-sema` | a PR to `zed-industries/extensions` per version bump (a tag can auto-**open** it, not merge it) | Yes, once listed | **Yes — a Zed maintainer must merge** |
| `helix-sema` | a PR to `helix-editor/helix` core | With the next Helix release | **Yes — upstream merge** |
| `sema.nvim`, `sema.vim` | push to `main` — plugin managers track the branch | On the user's next plugin update | No |
| `tree-sitter-sema` | push tag `v*` | Consumers pin their own revision | No |
| `ui` | push tag `v*` → npm (Trusted Publishing, OIDC) | Dependents bump themselves | No |

Consequences worth internalising:

- **MELPA needs no tag.** `sema-mode` is on MELPA *unstable*, which builds from
  the default branch on a schedule, so merging to `main` already ships it. A tag
  is only needed to appear on **MELPA Stable**, which builds from tags.
- **JetBrains and Zed cannot be finished by us.** Both need a human on the other
  side. Tag/PR, then say the release is *submitted*, not *shipped*.
- **Zed: a tag does not publish, but it can author the PR.** Both a first
  submission and every later version bump go through a PR to
  `zed-industries/extensions` that updates the submodule commit *and* the
  `version` in `extensions.toml` (`zed.dev/docs/extensions/developing-extensions`).
  Zed's own bot (`app/zed-zippy`) opens *and* self-merges those bumps off a
  release tag — but only for extensions living in Zed's orgs: of its last 60
  merged PRs, 56 were `zed-extensions/*` and 1 `zed-industries/*`, **none from a
  third-party org**. For `sema-lisp/zed-sema` the merge is done by a Zed
  maintainer. The community action `huacnlee/zed-extension-action` triggers on a
  `v*` tag and opens the PR for us; it cannot merge it. Do not assume a tag ships
  a Zed release — check `extensions.toml` for the version.
- **VS Code + Open VSX + Package Control are the whole win from a tag push** —
  three registries, no human gate. Do these first.

### Version source of truth differs per repo — check before tagging

- `vscode-sema` — **the tag wins**: `publish.yml` runs `npm pkg set version`
  from the tag, so `package.json` is overwritten at publish time. Bump it in the
  repo anyway so the committed value is not misleading.
- `intellij-sema` — **`gradle.properties` wins**: `pluginVersion` also selects
  the Marketplace channel (a pre-release suffix publishes to `beta`). The
  release workflow **fails when the tag does not match it**. Bump, commit, then
  tag.
- `sublime-sema` — **the tag is the only version**; nothing in the repo declares
  one. Existing tags are bare semver (`0.3.2`), not `v`-prefixed.
- `ui`, `tree-sitter-sema` — tag `v*`.

### Stale monorepo-split tags — do not push tags blindly

`intellij-sema`, `emacs-sema`, `zed-sema`, `helix-sema`, and `sema.vim` each
carry ~30–43 **local-only** `v1.x` tags (up to `v1.28.1`) inherited when they
were split out of `sema-lisp/sema`. **None of them exist on any remote**, and
they are not plugin releases — `intellij-sema`'s first Marketplace version is
`1.0.0`, published long after `v1.28.1`.

- **Never run `git push --tags`** in a member repo. It would publish dozens of
  meaningless tags and, in `intellij-sema`, fire the release workflow once per
  tag. Push one tag explicitly: `git push origin v1.1.0`.
- Do not read those tags as release history, and do not compute "commits since
  the last release" from them — compare against the registry's published
  version instead.

## Jake from the workspace root

`jake -l` lists every member's recipes namespaced (`sema.build`, `ui.test`,
`ts.test`, `intellij.test`, `vscode.package`) plus workspace aggregates. Common:

| Command | Effect |
| --- | --- |
| `jake status` | git status across all members + open PR count per repo |
| `jake update-all` | fast-forward every member on `main` |
| `jake bootstrap` | clone missing members and install `sccache`/`cargo-sweep` (or `./scripts/ws.sh bootstrap`) |
| `jake foreach cmd='git fetch'` | run a command in every member |
| `jake pin` | write `repos.lock` — a dir/repo/SHA snapshot |
| `jake wt-new name=<n> [branch=<b>] [member=sema]` | create a worktree under `.worktrees/` |
| `jake wt-rm name=<n>` | remove a worktree (cargo-cleans its target first) |
| `jake wt-list` | list all worktrees; flag any outside `.worktrees/` |
| `jake sweep [days=3]` | reclaim stale build artifacts across ALL targets |
| `jake sweep-preview [days=3]` | show what `sweep` would reclaim (deletes nothing) |
| `jake sweep-cap [max=10GB]` | cap EACH `target/` at a size, oldest artifacts first |
| `jake sweep-cap-preview [max=10GB]` | show what `sweep-cap` would reclaim |
| `jake target-sizes` | size of every `target/` + sccache + free space |
| `jake sema.<r>` / `jake ui.<r>` | a specific member's recipe |

The Jakefile `@import`s each member's **`@rooted`** Jakefile, so a missing member
makes `jake` fail to parse until you `bootstrap`.

## Worktrees — HARD REQUIREMENT

Git worktrees are how parallel agents get isolation, but ungoverned they scatter
across the disk and their `target/` dirs filled the volume to `ENOSPC` on
2026-07-10. Therefore:

- **Every new worktree MUST be created with `jake wt-new`** (member defaults to
  `sema`): `jake wt-new name=fix-x branch=fix/x`. It places the worktree at
  **`/Users/helge/code/sema/.worktrees/<name>` and nowhere else**.
- **NEVER create a worktree anywhere else** — not as a bare `sema-*` sibling at
  the workspace root, not in a member's own `.worktrees/`, not under `$HOME` or
  `/tmp`, and **never `git worktree add` by hand.** `.worktrees/` at the
  workspace root is the single sanctioned location.
- **Remove worktrees ONLY with `jake wt-rm name=<n>`** — it `cargo clean`s the
  target (reclaiming the space) before `git worktree remove` + `prune`. Never
  `rm -rf` a worktree dir.
- **Existing out-of-policy worktrees are WIP — do NOT move, delete, or "fix"
  them.** `jake wt-list` marks them `OUT-OF-POLICY`; the rule binds **new**
  worktrees only. Current known WIP lives outside `.worktrees/` (e.g. bare
  `sema-*` siblings, `sema/.worktrees/*`, `~/.codex/worktrees/*`).

## Disk hygiene & build cache — MUST follow

Rust builds here are governed by the workspace-local `/.cargo/config.toml` (cargo
discovers it by walking up from any member/worktree; it does **not** touch
`~/.cargo`, unrelated projects, or the mono's cargo-dist release/CI builds):

- **Incremental compilation is ON (cargo default); the sccache wrapper is OFF**
  (policy flipped 2026-07-17 — see `sema/docs/build-time-report.md`: sccache
  cannot help edited code, hard-fails on `-C incremental`, and the ENOSPC driver
  was per-worktree test binaries, not incremental caches). Do NOT re-add a
  `rustc-wrapper` to `/.cargo/config.toml`; for a one-off cached clean build run
  `CARGO_INCREMENTAL=0 RUSTC_WRAPPER=sccache cargo build` explicitly.
- **`cargo-sweep` is a required tool** (`jake bootstrap` installs it); `sccache`
  is optional (opt-in per command as above).
- **Reclaim space with `jake sweep [days=3]`** — recursively sweeps every
  `target/` under the workspace (members + worktrees), removing only regenerable
  artifacts older than N days; fresh/in-flight builds are kept. Preview first
  with `jake sweep-preview`. Inspect usage with `jake target-sizes`.
- **Run `jake sweep` when finishing worktrees or under disk pressure.** Unmanaged
  per-worktree `target/` dirs (cargo never GCs superseded artifacts — one hit
  20G of orphaned binaries) caused the 2026-07-10 ENOSPC outage. Incremental
  caches (~1.3G per worktree) make sweeping worktrees promptly MORE important,
  not less — use `jake sweep days=1` during multi-worktree crunches. Prefer
  `jake wt-rm` (which cleans as it removes) over leaving dead worktrees around.
- **When `jake sweep` reclaims nothing, use `jake sweep-cap [max=10GB]`.** An
  age-based sweep is a no-op while every artifact is fresh, which is exactly the
  state a release is in: each version bump compiles a new set, cargo keeps the
  superseded ones, and `days=1` still matches nothing. `sweep-cap` evicts the
  least-recently-used artifacts until each `target/` is under `max`, regardless
  of age. During the 1.34.x releases `sema/target` reached **52G** this way and
  the linker began failing with `ld: write() failed, errno=28` — which reads as
  unrelated test flakiness, not a full disk. `sweep-cap` reclaimed 37G, then 17G.
  Reach for it whenever a build fails with errno 28, a linker error, or tests
  start failing in ways that do not reproduce in isolation.

## Constraints

- **Don't move, rename, or delete member dirs** — it breaks `repos.tsv` and the
  Jakefile `@import`s. To add a member: clone it, add a `repos.tsv` line, and (if
  it has a `@rooted` Jakefile) add an `@import … as <ns>` to the Jakefile.
- **Don't convert members to submodules.** The manifest+clone model is deliberate
  (no detached-HEAD / two-step-commit friction).
- **Secrets live in `.env`** (gitignored, loaded via `@dotenv`). Never commit real
  keys; `.env.example` is the template.
- Non-`sema-lisp` scratch dirs may exist here; they're
  gitignored and not workspace members — leave them alone unless asked.
- The `git stash` / `git checkout --` cautions from `sema/AGENTS.md` apply in
  every member: prefer worktrees; never clobber another agent's uncommitted work.

## Writing style — plain technical English (all members)

Applies to chat replies, code comments, commit messages, PR text, and docs in
every member repo. Full rule in `sema/AGENTS.md` ("Writing style"); summary:

- Use common words and short, direct sentences (ASD-STE100 where practical).
- One term per concept; use names from the code verbatim.
- State problem, cause, and fix explicitly, in that order.
- No metaphors, invented idioms, or rhetorical language ("load-bearing",
  "sharp edge", "seam", "beachhead", "north star", "substrate", and similar are
  banned unless literally technical). Report what changed, why, and what proves
  it.
