*   Support DISTINCT ON queries across all databases

    PostgreSQL uses native `DISTINCT ON` syntax for optimal performance.
    Other databases (MySQL, SQLite) use `ROW_NUMBER()` window functions
    to achieve equivalent behavior.

    ```ruby
    User.distinct_on(:name)

    # PostgreSQL:
    #=> SELECT DISTINCT ON (name) * FROM users

    # MySQL/SQLite:
    #=> SELECT * FROM (
    #     SELECT *, ROW_NUMBER() OVER (PARTITION BY name ORDER BY ...) AS __ar_row_num__
    #     FROM users
    #   ) __ar_distinct_on__ WHERE __ar_row_num__ = 1
    ```

    *Ali Ismayilov*, *Claude*

*   Fix negative scopes for enums to include records with `nil` values.

    *fatkodima*

*   Improve support for SQLite database URIs.

    The `db:create` and `db:drop` tasks now correctly handle SQLite database URIs, and the
    SQLite3Adapter will create the parent directory if it does not exist.

    *Mike Dalessio*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activerecord/CHANGELOG.md) for previous changes.
