
*   PostgreSQL: Fix db:structure:load silent failure on SQL error

    The command line flag "-v ON_ERROR_STOP=1" should be used
    when invoking psql to make sure errors are not suppressed.

    Example:

        psql -v ON_ERROR_STOP=1 -q -f awesome-file.sql my-app-db

    Fixes #23818.

    *Ralin Chimev*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
