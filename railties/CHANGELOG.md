*   Defer route drawing to the first request, or when url_helpers are called

    Executes the first routes reload in middleware, or when a route set's
    url_helpers receives a route call / asked if it responds to a route.
    Previously, this was executed unconditionally on boot, which can
    slow down boot time unnecessarily for larger apps with lots of routes.

    Environments like production that have `config.eager_load = true` will
    continue to eagerly load routes on boot.

    *Gannon McGibbon*

*   Add Rubocop and GitHub Actions to plugin generator.
    This can be skipped using --skip-rubocop and --skip-ci.

    *Chris Oliver*

*   Use Kamal for deployment by default, which includes generating a Rails-specific config/deploy.yml.
    This can be skipped using --skip-kamal. See more: https://kamal-deploy.org/

    *DHH*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md) for previous changes.
