# Warren v0.19.2 downstream patches

These source files override matching files in the pinned `@os-eco/warren-cli` npm package during the Nix server build. Rebase them against the pinned source before updating Warren.

Automatic scheduler work (`cron`, `scheduled`, `ci-fixer`, `plan-run`) defaults to one non-terminal run per Warren instance. Configure `WARREN_AUTOMATIC_MAX_CONCURRENT_RUNS` to a positive per-instance limit. Set `WARREN_AUTOMATIC_RUN_WINDOW=HH:MM-HH:MM@IANA/Timezone` to apply a local-time window; unset leaves scheduling unrestricted and invalid values fail closed. Manual runs remain outside this admission gate.

Automatic provider retries retain the failed run's provider/model, so a failed Lemonade request stays on Lemonade. Due work remains eligible for a later scheduler tick after capacity returns.
