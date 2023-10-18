*   Postgres: use ANY instead of IN for array inclusion queries

    Previously, queries like `where(id: [1, 2])` generated the SQL `id IN (1, 2)`.
    Now `id = ANY ('{1,2}')` is generated instead, and `where.not` generates `id != ALL ('{1,2}')`.

    This brings several advantages:

    * the query can now be a prepared statement
    * query parsing is faster
    * duplicate entries in `pg_stat_statements` can be avoided
    * queries are less likely to be truncated in `pg_stat_activity`

    *Sean Linsley*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*


Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
