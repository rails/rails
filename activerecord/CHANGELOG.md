*   Dump the schema or structure of a database when calling db:migrate:name

    In previous versions of Rails, `rails db:migrate` would dump the schema of the database. In Rails 6, that holds true (`rails db:migrate` dumps all databases' schemas), but `rails db:migrate:name` does not share that behavior.

    Going forward, calls to `rails db:migrate:name` will dump the schema (or structure) of the database being migrated.

    *Kyle Thompson*

*   Reset the `ActiveRecord::Base` connection after `rails db:migrate:name`

    When `rails db:migrate` has finished, it ensures the `ActiveRecord::Base` connection is reset to its original configuration. Going forward, `rails db:migrate:name` will have the same behavior.

    *Kyle Thompson*

*   Disallow calling `connected_to` on subclasses of `ActiveRecord::Base`.

    Behavior has not changed here but the previous API could be misleading to people who thought it would switch connections for only that class. `connected_to` switches the context from which we are getting connections, not the connections themselves.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Add support for horizontal sharding to `connects_to` and `connected_to`.

    Applications can now connect to multiple shards and switch between their shards in an application. Note that the shard swapping is still a manual process as this change does not include an API for automatic shard swapping.

    Usage:

    Given the following configuration:

    ```yaml
    # config/database.yml
    production:
      primary:
        database: my_database
      primary_shard_one:
        database: my_database_shard_one
    ```

    Connect to multiple shards:

    ```ruby
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true

      connects_to shards: {
        default: { writing: :primary },
        shard_one: { writing: :primary_shard_one }
      }
    ```

    Swap between shards in your controller / model code:

    ```ruby
    ActiveRecord::Base.connected_to(shard: :shard_one) do
      # Read from shard one
    end
    ```

    The horizontal sharding API also supports read replicas. See guides for more details.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Deprecate `spec_name` in favor of `name` on database configurations.

    The accessors for `spec_name` on `configs_for` and `DatabaseConfig` are deprecated. Please use `name` instead.

    Deprecated behavior:

    ```ruby
    db_config = ActiveRecord::Base.configs_for(env_name: "development", spec_name: "primary")
    db_config.spec_name
    ```

    New behavior:

    ```ruby
    db_config = ActiveRecord::Base.configs_for(env_name: "development", name: "primary")
    db_config.name
    ```

    *Eileen M. Uchitelle*

*   Add additional database-specific rake tasks for multi-database users.

    Previously, `rails db:create`, `rails db:drop`, and `rails db:migrate` were the only rails tasks that could operate on a single
    database. For example:

    ```
    rails db:create
    rails db:create:primary
    rails db:create:animals
    rails db:drop
    rails db:drop:primary
    rails db:drop:animals
    rails db:migrate
    rails db:migrate:primary
    rails db:migrate:animals
    ```

    With these changes, `rails db:schema:dump`, `rails db:schema:load`, `rails db:structure:dump`, `rails db:structure:load` and
    `rails db:test:prepare` can additionally operate on a single database. For example:

    ```
    rails db:schema:dump
    rails db:schema:dump:primary
    rails db:schema:dump:animals
    rails db:schema:load
    rails db:schema:load:primary
    rails db:schema:load:animals
    rails db:structure:dump
    rails db:structure:dump:primary
    rails db:structure:dump:animals
    rails db:structure:load
    rails db:structure:load:primary
    rails db:structure:load:animals
    rails db:test:prepare
    rails db:test:prepare:primary
    rails db:test:prepare:animals
    ```

    *Kyle Thompson*

*   Add support for `strict_loading` mode on association declarations.

    Raise an error if attempting to load a record from an association that has been marked as `strict_loading` unless it was explicitly eager loaded.

    Usage:

    ```
    >> class Developer < ApplicationRecord
    >>   has_many :projects, strict_loading: true
    >> end
    >>
    >> dev = Developer.first
    >> dev.projects.first
    => ActiveRecord::StrictLoadingViolationError: The projects association is marked as strict_loading and cannot be lazily loaded.
    ```

    *Kevin Deisz*

*   Add support for `strict_loading` mode to prevent lazy loading of records.

    Raise an error if a parent record is marked as `strict_loading` and attempts to lazily load its associations. This is useful for finding places you may want to preload an association and avoid additional queries.

    Usage:

    ```
    >> dev = Developer.strict_loading.first
    >> dev.audit_logs.to_a
    => ActiveRecord::StrictLoadingViolationError: Developer is marked as strict_loading and AuditLog cannot be lazily loaded.
    ```

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Add support for PostgreSQL 11+ partitioned indexes when using `upsert_all`.

    *Sebastián Palma*

*   Adds support for `if_not_exists` to `add_column` and `if_exists` to `remove_column`.

    Applications can set their migrations to ignore exceptions raised when adding a column that already exists or when removing a column that does not exist.

    Example Usage:

    ```ruby
    class AddColumnTitle < ActiveRecord::Migration[6.1]
      def change
        add_column :posts, :title, :string, if_not_exists: true
      end
    end
    ```

    ```ruby
    class RemoveColumnTitle < ActiveRecord::Migration[6.1]
      def change
        remove_column :posts, :title, if_exists: true
      end
    end
    ```

    *Eileen M. Uchitelle*

*   Regexp-escape table name for MS SQL Server.

    Add `Regexp.escape` to one method in ActiveRecord, so that table names with regular expression characters in them work as expected. Since MS SQL Server uses "[" and "]" to quote table and column names, and those characters are regular expression characters, methods like `pluck` and `select` fail in certain cases when used with the MS SQL Server adapter.

    *Larry Reid*

*   Store advisory locks on their own named connection.

    Previously advisory locks were taken out against a connection when a migration started. This works fine in single database applications but doesn't work well when migrations need to open new connections which results in the lock getting dropped.

    In order to fix this we are storing the advisory lock on a new connection with the connection specification name `AdvisoryLockBase`. The caveat is that we need to maintain at least 2 connections to a database while migrations are running in order to do this.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Allow schema cache path to be defined in the database configuration file.

    For example:

    ```yaml
    development:
      adapter: postgresql
      database: blog_development
      pool: 5
      schema_cache_path: tmp/schema/main.yml
    ```

    *Katrina Owen*

*   Deprecate `#remove_connection` in favor of `#remove_connection_pool` when called on the handler.

    `#remove_connection` is deprecated in order to support returning a `DatabaseConfig` object instead of a `Hash`. Use `#remove_connection_pool`, `#remove_connection` will be removed in 6.2.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Deprecate `#default_hash` and it's alias `#[]` on database configurations.

    Applications should use `configs_for`. `#default_hash` and `#[]` will be removed in 6.2.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Add scale support to `ActiveRecord::Validations::NumericalityValidator`.

    *Gannon McGibbon*

*   Find orphans by looking for missing relations through chaining `where.missing`:

    Before:

    ```ruby
    Post.left_joins(:author).where(authors: { id: nil })
    ```

    After:

    ```ruby
    Post.where.missing(:author)
    ```

    *Tom Rossi*

*   Ensure `:reading` connections always raise if a write is attempted.

    Now Rails will raise an `ActiveRecord::ReadOnlyError` if any connection on the reading handler attempts to make a write. If your reading role needs to write you should name the role something other than `:reading`.

    *Eileen M. Uchitelle*

*   Deprecate "primary" as the connection_specification_name for ActiveRecord::Base.

    `"primary"` has been deprecated as the `connection_specification_name` for `ActiveRecord::Base` in favor of using `"ActiveRecord::Base"`. This change affects calls to `ActiveRecord::Base.connection_handler.retrieve_connection` and `ActiveRecord::Base.connection_handler.remove_connection`. If you're calling these methods with `"primary"`, please switch to `"ActiveRecord::Base"`.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Add `ActiveRecord::Validations::NumericalityValidator` with
    support for casting floats using a database columns' precision value.

    *Gannon McGibbon*

*   Enforce fresh ETag header after a collection's contents change by adding
    ActiveRecord::Relation#cache_key_with_version. This method will be used by
    ActionController::ConditionalGet to ensure that when collection cache versioning
    is enabled, requests using ConditionalGet don't return the same ETag header
    after a collection is modified.

    Fixes #38078.

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
