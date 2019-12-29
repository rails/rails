*   Enforce fresh ETag header after a collection's contents change by adding
    ActiveRecord::Relation#cache_key_with_version. This method will be used by
    ActionController::ConditionalGet to ensure that when collection cache versioning
    is enabled, requests using ConditionalGet don't return the same ETag header
    after a collection is modified. Fixes #38078.

    *Aaron Lipman*

*   Skip test database when running `db:create` or `db:drop` in development
    with `DATABASE_URL` set.

    *Brian Buchalter*

*   Don't allow mutations on the database configurations hash.

    Freeze the configurations hash to disallow directly changing it. If applications need to change the hash, for example to create databases for parallelization, they should use the `DatabaseConfig` object directly.

    Before:

    ```ruby
    @db_config = ActiveRecord::Base.configurations.configs_for(env_name: "test", spec_name: "primary")
    @db_config.configuration_hash.merge!(idle_timeout: "0.02")
    ```

    After:

    ```ruby
    @db_config = ActiveRecord::Base.configurations.configs_for(env_name: "test", spec_name: "primary")
    config = @db_config.configuration_hash.merge(idle_timeout: "0.02")
    db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(@db_config.env_name, @db_config.spec_name, config)
    ```

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Remove `:connection_id` from the `sql.active_record` notification.

    *Aaron Patterson*, *Rafael Mendonça França*

*   The `:name` key will no longer be returned as part of `DatabaseConfig#configuration_hash`. Please use `DatabaseConfig#owner_name` instead.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   ActiveRecord's `belongs_to_required_by_default` flag can now be set per model.

    You can now opt-out/opt-in specific models from having their associations required
    by default.

    This change is meant to ease the process of migrating all your models to have
    their association required.

    *Edouard Chin*

*   The `connection_config` method has been deprecated, please use `connection_db_config` instead which will return a `DatabaseConfigurations::DatabaseConfig` instead of a `Hash`.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Retain explicit selections on the base model after applying `includes` and `joins`.

    Resolves #34889.

    *Patrick Rebsch*

*   The `database` kwarg is deprecated without replacement because it can't be used for sharding and creates an issue if it's used during a request. Applications that need to create new connections should use `connects_to` instead.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Allow attributes to be fetched from Arel node groupings.

    *Jeff Emminger*, *Gannon McGibbon*

*   A database URL can now contain a querystring value that contains an equal sign. This is needed to support passing PostgreSQL `options`.

    *Joshua Flanagan*

*   Calling methods like `establish_connection` with a `Hash` which is invalid (eg: no `adapter`) will now raise an error the same way as connections defined in `config/database.yml`.

    *John Crepezzi*

*   Specifying `implicit_order_column` now subsorts the records by primary key if available to ensure deterministic results.

    *Paweł Urbanek*

*   `where(attr => [])` now loads an empty result without making a query.

    *John Hawthorn*

*   Fixed the performance regression for `primary_keys` introduced MySQL 8.0.

    *Hiroyuki Ishii*

*   Add support for `belongs_to` to `has_many` inversing.

    *Gannon McGibbon*

*   Allow length configuration for `has_secure_token` method. The minimum length
    is set at 24 characters.

    Before:

    ```ruby
    has_secure_token :auth_token
    ```

    After:

    ```ruby
    has_secure_token :default_token             # 24 characters
    has_secure_token :auth_token, length: 36    # 36 characters
    has_secure_token :invalid_token, length: 12 # => ActiveRecord::SecureToken::MinimumLengthError
    ```

    *Bernardo de Araujo*

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

*   Make currency symbols optional for money column type in PostgreSQL.

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
