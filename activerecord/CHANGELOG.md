*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

*   The `db:prepare` task no longer loads seeds when a non-primary database is created.

    Previously, the `db:prepare` task would load seeds whenever a new database
    is created, leading to potential loss of data if a database is added to an
    existing environment.

    Introduces a new database config property `seeds` to control whether seeds
    are loaded during `db:prepare` which defaults to `true` for primary database
    configs and `false` otherwise.

    Fixes #53348.

    *Mike Dalessio*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md) for previous changes.
