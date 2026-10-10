# Warren 0.19.3-r6 consolidation and release plan

## Goal
Consolidate the current Warren packaging and recovery updates in the canonical repository, publish a versioned 0.19.3-r6 release, and make `~/devenv` consume it from GitHub rather than a local checkout.

## Non-goals
- Do not pull/recreate or otherwise modify running Podman instances; publish images for later consumption only.
- Do not use a local path as the Warren flake input in `~/devenv.yaml`.
- Do not discard dirty worktree changes or ignored project data while consolidating.

## Context
- PR #9 (`feat/warren-0.19.3-local-patches`) targets `main`; its existing build and image checks pass.
- Its manifest is already Warren 0.19.3, package revision 6; the publish workflow builds `cli`, `server`, `dockerImage`, and `agentImage`.
- Existing recovery and provider-retry patches are already present in PR #9. The unique recovery delta identified in the newer 0.19.3 worktree is using the parent's `salvageRef` as the follow-up base, with a regression test. A provider-retry test also needs to cover a recorded PR URL.
- `~/devenv/tools.nix` already installs `inputs.warren` and its `wr` alias. `~/devenv.yaml` currently sources Warren from a local path to a sibling checkout.
- No prior GitHub release or tag exists. Candidate release ref: `v0.19.3-r6`.

## Release plan
- Release tag: `v0.19.3-r6`.
- Version files: none; `nix/package-manifest.json` on PR #9 already declares upstream `0.19.3`, package revision `6`.
- Commit list: no previous release tag exists; PR #9 carries `2747719`, `cbcf28f`, `d397a4e`, `ae8c075`, and `cccbe82`, followed by the consolidation commit.
- Version-bump type: none beyond the existing package revision 6.
- Changelog draft:
  - Changed: rebase downstream Warren patches on CLI 0.19.3; publish CLI, server, server image, and agent image.
  - Fixed: follow-up runs continue from salvaged refs; provider-error retries are covered against already-created PRs.

## Blast radius
- `patches/warren/src/runs/spawn/continuation.ts` and its test: follow-ups resume from salvaged work.
- `patches/warren/src/runs/retry/provider-retry.admission.test.ts`: regression coverage for runs with a recorded PR.
- `patches/warren/README.md`: document the follow-up behavior.
- `release-plan.md`: record release contents and verification.
- `~/devenv.yaml` and generated `~/devenv.lock`: pin the published Warren source by GitHub tag.
- GitHub PR/branch, release tag, and GHCR server/agent images.

## Steps
1. Preserve the canonical worktree's pre-existing dirty changes in a Git stash; work from a consolidation branch based on PR #9. Verify clean status and base commit.
2. Port only the missing continuation salvage behavior and PR-URL retry test; retain the already more complete 0.19.3 reap/Kubernetes salvage implementations. Run the focused tests and inspect the full diff.
3. Run `nix flake check` and build the local CLI/server outputs. Use the GitHub image workflow to build and publish `dockerImage` and `agentImage`; avoid a local image build because only about 23 GiB is free on the root filesystem.
4. Commit and push the update to PR #9. Wait for CI; merge only through normal repository rules, without bypassing required review.
5. After merge, tag/release `v0.19.3-r6`; verify the workflow publishes versioned Warren and agent images.
6. Change `~/devenv.yaml` to the GitHub release ref, update `~/devenv.lock`, and smoke-test `warren` and `wr` from `devenv shell`.
7. Leave running Podman instances unchanged. Do not remove worktrees containing dirty or ignored user data.

## Tests and verification
- Run the focused Warren Bun tests for continuation salvage and provider retry admission against the 0.19.3 source.
- Run `nix flake check` plus `nix build .#cli .#server --no-link` in the canonical repo; verify the GitHub image workflow succeeds for both images.
- After release, run `devenv update warren`, then `devenv shell -- warren --version` and `devenv shell -- wr --version`.
- Confirm `~/devenv.yaml` and `~/devenv.lock` contain a GitHub Warren input and no `path:` Warren source.

## Verification results (pre-publish)
- `nix flake check --accept-flake-config`: passed; Nix reports only the configured `x86_64-linux` system and emits non-fatal app metadata/renamed-attribute warnings.
- `nix build --accept-flake-config .#cli .#server --no-link`: passed; Warren CLI and server both report 0.19.3.
- `nix build --accept-flake-config .#cli^wr --no-link`: passed; the `wr` output reports 0.19.3.
- Focused Bun tests: 26 passed, 0 failed across continuation, provider retry, reap salvage, and Kubernetes salvage.
- `bun audit`: no vulnerabilities across 129 packages. Frozen dry-run install passed. `bun outdated` reports bun2nix 2.0.8 while 2.1.2 is latest; not changed in this release scope.

## Rollback
- Before tagging, revert the consolidation commit if verification fails; retain the original stash and worktrees.
- Never move a published tag. If a released artifact is faulty, cut a new package revision/tag and publish a forward fix.
- If the devenv pin fails, restore its prior input only as a temporary rollback; do not restore the local-path dependency.

## Open questions
- None for the requested artifact build. Live Podman rollout remains explicitly out of scope pending separate approval.

### For Executor
Read order: this plan, `patches/warren/src/runs/spawn/continuation.ts`, the provider-retry admission test, then `~/devenv.yaml` and `~/devenv.lock`.
Assumed working state: canonical repo is on `consolidate/warren-0.19.3-r6`; the original dirty main worktree changes are preserved in `stash@{0}`.
Owned files: `release-plan.md`, the three Warren patch files above, and `~/devenv.yaml`/`~/devenv.lock` after release.
Verification commands: focused Warren tests, `nix flake check`, local CLI/server outputs, GitHub image workflow, and the two post-release `devenv shell -- ... --version` smoke checks.
