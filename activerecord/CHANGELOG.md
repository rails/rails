*   Record environment in database before running migrations

    The environment is now set in the database before running DB migrations,
    so in the event of a migration error on a new database, destructive rake
    tasks can be run.

    Fixes #28001.

    *Dominic Cleal*

*   Load only needed records on `ActiveRecord::Relation#inspect`.

    Instead of loading all records and returning only a subset of those, just
    load the records as needed.

    Fixes #25537.

    *Hendy Tanata*

Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activerecord/CHANGELOG.md) for previous changes.
