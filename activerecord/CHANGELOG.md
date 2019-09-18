*   Deprecate `DatabaseConfigurations#to_h`. These connection hashes are still available via `ActiveRecord::Base.configurations.configs_for`.

    *Eileen Uchitelle*, *John Crepezzi*

*   Add `DatabaseConfig#configuration_hash` to return database configuration hashes with symbol keys, and use all symbol-key configuration hashes internally. Deprecate `DatabaseConfig#config` which returns a String-keyed `Hash` with the same values.

    *John Crepezzi*, *Eileen Uchitelle*

*   Allow column names to be passed to `remove_index` positionally along with other options.

    Passing other options can be necessary to make `remove_index` correctly reversible.

    Before:

        add_index    :reports, :report_id               # => works
        add_index    :reports, :report_id, unique: true # => works
        remove_index :reports, :report_id               # => works
        remove_index :reports, :report_id, unique: true # => ArgumentError

    After:

        remove_index :reports, :report_id, unique: true # => works

    *Eugene Kenny*

*   Allow bulk `ALTER` statements to drop and recreate indexes with the same name.

    *Eugene Kenny*

*   `insert`, `insert_all`, `upsert`, and `upsert_all` now clear the query cache.

    *Eugene Kenny*

*   Call `while_preventing_writes` directly from `connected_to`.

    In some cases application authors want to use the database switching middleware and make explicit calls with `connected_to`. It's possible for an app to turn off writes and not turn them back on by the time we call `connected_to(role: :writing)`.

    This change allows apps to fix this by assuming if a role is writing we want to allow writes, except in the case it's explicitly turned off.

    *Eileen M. Uchitelle*

*   Improve detection of ActiveRecord::StatementTimeout with mysql2 adapter in the edge case when the query is terminated during filesort.

    *Kir Shatrov*

*   Stop trying to read yaml file fixtures when loading Active Record fixtures.

    *Gannon McGibbon*

*   Deprecate `.reorder(nil)` with `.first` / `.first!` taking non-deterministic result.

    To continue taking non-deterministic result, use `.take` / `.take!` instead.

    *Ryuta Kamizono*

*   Ensure custom PK types are casted in through reflection queries.

    *Gannon McGibbon*

*   Preserve user supplied joins order as much as possible.

    Fixes #36761, #34328, #24281, #12953.

    *Ryuta Kamizono*

*   Allow `matches_regex` and `does_not_match_regexp` on the MySQL Arel visitor.

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
