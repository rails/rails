*   Use Kamal for deployment by default, which includes generating a Rails-specific config/deploy.yml.
    This can be skipped using --skip-kamal. See more: https://kamal-deploy.org/

    *DHH* 

*   Defer route drawing to the first request, or when url_helpers are called

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md) for previous changes.
