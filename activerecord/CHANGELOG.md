*   Allow matches_regex on MySQL 

    *James Pearson*
    
*   Allow specifying fixtures to be ignored by setting `ignore` in YAML file's '_fixture' section.

    *Tongfei Gao*

*   Make the DATABASE_URL env variable only affect the primary connection. Add new env variables for multiple databases.

    *John Crepezzi*, *Eileen Uchitelle*

*   Add a warning for enum elements with 'not_' prefix.

        class Foo
          enum status: [:sent, :not_sent]
        end

    *Edu Depetris*

*   Make currency symbols optional for money column type in PostgreSQL

    *Joel Schneider*

*   Add support for beginless ranges, introduced in Ruby 2.7.

    *Josh Goodall*

*   Add database_exists? method to connection adapters to check if a database exists.

    *Guilherme Mansur*

*   Loading the schema for a model that has no `table_name` raises a `TableNotSpecified` error.

    *Guilherme Mansur*, *Eugene Kenny*

*   PostgreSQL: Fix GROUP BY with ORDER BY virtual count attribute.

    Fixes #36022.

    *Ryuta Kamizono*

*   Make ActiveRecord `ConnectionPool.connections` method thread-safe.

    Fixes #36465.

    *Jeff Doering*

*   Add support for multiple databases to `rails db:abort_if_pending_migrations`.

    *Mark Lee*

*   Fix sqlite3 collation parsing when using decimal columns.

    *Martin R. Schuster*

*   Fix invalid schema when primary key column has a comment.

    Fixes #29966.

    *Guilherme Goettems Schneider*

*   Fix table comment also being applied to the primary key column.

    *Guilherme Goettems Schneider*

*   Allow generated `create_table` migrations to include or skip timestamps.

    *Michael Duchemin*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activerecord/CHANGELOG.md) for previous changes.
