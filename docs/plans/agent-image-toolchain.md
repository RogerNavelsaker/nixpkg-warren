# Warren Agent Image Toolchain

## Goal
Build a reproducible Warren agent image with Python/pip/venv/uv, Node/npm/Bun, the Seeds/Mulch/Canopy/Sapling/Plot/Pi CLIs, and the requested shell utilities.

## Non-goals
- Do not add Rust/Cargo, Go, or JDK; these were not requested and upstream Warren explicitly omits them.
- Do not modify or restart either live Warren instance in this change. Rollout remains separately approval-gated.
- Do not install tools at container startup or rely on runtime network access.
- Do not change Warren run history, scheduler policy, or unrelated deployment worktrees.

## Context
- The published r6 image lacks Python, uv, Node/npm, sed, awk, which, diff, ldd, strings, and ripgrep; observed run events reported several of these missing.
- `nix/agent-docker.nix` composes an immutable `buildEnv`; `flake.nix` already consumes the RogerNavelsaker Nix packages for Pi, Seeds, and Mulch.
- Existing RogerNavelsaker flakes provide Canopy and Plot. No `nixpkg-sapling` exists; upstream `@os-eco/sapling-cli` v0.3.2 exposes `sapling` and `sp`.
- Nixpkgs does not bundle the requested commands into `coreutils`: use `gnused`, `gawk`, `which`, `diffutils`, `glibc.bin` (`ldd`), `binutils` (`strings`), and `ripgrep` (`rg`). `python3Packages.pip` provides pip; `nodejs_22` includes npm; Bun is already present.
- Sapling's `getCurrentVersion()` reads its installed `package.json`; the Nix package must preserve that data or patch the function to its pinned version, following the existing Mulch packaging pattern.

## Blast radius
- New public packaging repository `RogerNavelsaker/nixpkg-sapling`, pinned to upstream v0.3.2.
- Warren `flake.nix` and `flake.lock`: add remote Canopy, Plot, and Sapling inputs, following the shared nixpkgs/bun2nix inputs.
- Warren `nix/agent-docker.nix`: include the requested runtimes, ecosystem CLIs, and utility packages.
- Warren `.github/workflows/publish.yml`: smoke-check expected commands and Python venv creation in the built image.
- Warren `nix/package-manifest.json`: increment package revision for the changed image.

## Steps
1. Create `nixpkg-sapling` using the existing Bun2nix flake conventions. Package the pinned npm v0.3.2 CLI, expose `sapling` and `sp`, and patch its package-version lookup to the manifest version. Verify with `nix flake check` and build/run both CLI aliases.
2. Add Sapling, Canopy, and Plot as remote Warren flake inputs and wire their package outputs alongside existing Pi/Seeds/Mulch packages. Verify flake evaluation and lockfile source URLs.
3. Add Python/pip/uv, Node 22/npm/Bun, the seven utility providers, and all requested CLIs to the agent image. Increment the package revision. Verify the image build and command/venv smoke checks.
4. Update the image-publish workflow's smoke check so future images fail CI when a required executable or Python venv is missing. Run the repository flake checks and inspect the complete diff.

## Tests and verification
- Sapling package: `nix flake check` and `nix build .#default`; run `sapling --version --json` and `sp --version --json` from the built package.
- Warren: `nix flake check`, `nix build .#agentImage`, then load the image and check every required command with `command -v`; run Node/npm/Bun/Python/uv version commands and create a temporary `python3 -m venv`.
- CI: confirm its image smoke step performs the same checks before publishing.
- Review `git diff --check`, `git diff`, package lock URLs, and final worktree status.

## Rollback
Revert the Warren input/wiring/image/workflow/manifest changes and remove the unmerged `nixpkg-sapling` repository if it is not adopted. Do not restore or mutate live database state; no deployment is part of this plan.

## Open questions
- None for the requested package set. Cargo remains excluded unless requested separately.

### For Executor
Read order: this plan; `flake.nix`; `nix/agent-docker.nix`; `.github/workflows/publish.yml`; existing `nixpkg-seeds` and `nixpkg-mulch` packaging definitions.
Assumed working state: execute in the clean `feat/agent-image-toolchain` worktree based on `origin/main`; preserve all other Warren worktrees and the dirty deployment repository.
Owned files: Warren files listed under Blast radius; files in the new `nixpkg-sapling` repository only.
Verification commands: run the exact package and Warren checks listed above. Do not deploy to either live instance.
