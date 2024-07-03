*   Introduce `mariadb-mysql` and `mariadb-trilogy` database options for `rails new`

    When used with the `--devcontainer` flag, these options will use `mariadb` as the database for the
    Dev Container. The original `mysql` and `trilogy` options will use `mysql`. Users who are not
    generating a Dev Container do not need to use the new options.

    *Andrew Novoselac*

*   Deprecate `bin/rake stats` in favor of `bin/rails stats`.

    *Juan Vásquez*

*   Add internal page `/rails/info/notes`, that displays the same information as `bin/rails notes`.

    *Deepak Mahakale*

*   Add Rubocop and GitHub Actions to plugin generator.
    This can be skipped using --skip-rubocop and --skip-ci.

    *Chris Oliver*

*   Use Kamal for deployment by default, which includes generating a Rails-specific config/deploy.yml.
    This can be skipped using --skip-kamal. See more: https://kamal-deploy.org/

    *DHH*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md) for previous changes.
