*   When running `db:migrate` on a fresh database, load all databases schemas before running migrations.

    *Marek Kasztelnik*

*   NULLS NOT DISTINCT works with UNIQUE CONSTRAINT as well as UNIQUE INDEX.

    *Ryuta Kamizono*

*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md) for previous changes.
