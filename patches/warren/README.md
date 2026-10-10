# Warren v0.19.3 downstream patches

These source files override matching files in the pinned `@os-eco/warren-cli` npm package during the Nix server build. Rebase them against the pinned source before updating Warren.

Automatic run admission, rescue dispatch, and provider-error salvage are provided by upstream 0.19.3. Local overrides add Pi thinking controls and action-role handoff, avoid retrying work already pushed, and salvage tracked changes only (never untracked files).

Follow-up runs start from the parent's salvage ref when available.
