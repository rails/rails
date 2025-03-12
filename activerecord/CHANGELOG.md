## Rails 8.0.2 (March 12, 2025) ##

*   No changes.


## Rails 8.0.2 (March 12, 2025) ##

*   Fix inverting `rename_enum_value` when `:from`/`:to` are provided.

    *fatkodima*

*   Prevent persisting invalid record.

    *Edouard Chin*

*   Fix inverting `drop_table` without options.

    *fatkodima*

*   Fix count with group by qualified name on loaded relation.

    *Ryuta Kamizono*

*   Fix `sum` with qualified name on loaded relation.

    *Chris Gunther*

*   The SQLite3 adapter quotes non-finite Numeric values like "Infinity" and "NaN".

    *Mike Dalessio*

*   Handle libpq returning a database version of 0 on no/bad connection in `PostgreSQLAdapter`.

    Before, this version would be cached and an error would be raised during connection configuration when
    comparing it with the minimum required version for the adapter. This meant that the connection could
    never be successfully configured on subsequent reconnection attempts.

    Now, this is treated as a connection failure consistent with libpq, raising a `ActiveRecord::ConnectionFailed`
    and ensuring the version isn't cached, which allows the version to be retrieved on the next connection attempt.

    *Joshua Young*, *Rian McGuire*

*   Fix error handling during connection configuration.

    Active Record wasn't properly handling errors during the connection configuration phase.
    This could lead to a partially configured connection being used, resulting in various exceptions,
    the most common being with the PostgreSQLAdapter raising `undefined method `key?' for nil`
    or `TypeError: wrong argument type nil (expected PG::TypeMap)`.

    *Jean Boussier*

*   Fix a case where a non-retryable query could be marked retryable.

    *Hartley McGuire*

*   Handle circular references when autosaving associations.

    *zzak*

*   PoolConfig no longer keeps a reference to the connection class.

    Keeping a reference to the class caused subtle issues when combined with reloading in
    development. Fixes #54343.

    *Mike Dalessio*

*   Fix SQL notifications sometimes not sent when using async queries.

    ```ruby
    Post.async_count
    ActiveSupport::Notifications.subscribed(->(*) { "Will never reach here" }) do
      Post.count
    end
    ```

    In rare circumstances and under the right race condition, Active Support notifications
    would no longer be dispatched after using an asynchronous query.
    This is now fixed.

    *Edouard Chin*

*   Fix support for PostgreSQL enum types with commas in their name.

    *Arthur Hess*

*   Fix inserts on MySQL with no RETURNING support for a table with multiple auto populated columns.

    *Nikita Vasilevsky*

*   Fix joining on a scoped association with string joins and bind parameters.

    ```ruby
    class Instructor < ActiveRecord::Base
      has_many :instructor_roles, -> { active }
    end

    class InstructorRole < ActiveRecord::Base
      scope :active, -> {
        joins("JOIN students ON instructor_roles.student_id = students.id")
        .where(students { status: 1 })
      }
    end

    Instructor.joins(:instructor_roles).first
    ```

    The above example would result in `ActiveRecord::StatementInvalid` because the
    `active` scope bind parameters would be lost.

    *Jean Boussier*

*   Fix a potential race condition with system tests and transactional fixtures.

    *Sjoerd Lagarde*

*   Fix autosave associations to no longer validated unmodified associated records.

    Active Record was incorrectly performing validation on associated record that
    weren't created nor modified as part of the transaction:

    ```ruby
    Post.create!(author: User.find(1)) # Fail if user is invalid
    ```

    *Jean Boussier*

*   Remember when a database connection has recently been verified (for
    two seconds, by default), to avoid repeated reverifications during a
    single request.

    This should recreate a similar rate of verification as in Rails 7.1,
    where connections are leased for the duration of a request, and thus
    only verified once.

    *Matthew Draper*


## Rails 8.0.1 (December 13, 2024) ##

*   Fix removing foreign keys with :restrict action for MySQL.

    *fatkodima*

*   Fix a race condition in `ActiveRecord::Base#method_missing` when lazily defining attributes.

    If multiple thread were concurrently triggering attribute definition on the same model,
    it could result in a `NoMethodError` being raised.

    *Jean Boussier*

*   Fix MySQL default functions getting dropped when changing a column's nullability.

    *Bastian Bartmann*

*   Fix `add_unique_constraint`/`add_check_constraint`/`add_foreign_key` to be revertible when given invalid options.

    *fatkodima*

*   Fix asynchronous destroying of polymorphic `belongs_to` associations.

    *fatkodima*

*   Fix `insert_all` to not update existing records.

    *fatkodima*

*   `NOT VALID` constraints should not dump in `create_table`.

    *Ryuta Kamizono*

*   Fix finding by nil composite primary key association.

    *fatkodima*

*   Properly reset composite primary key configuration when setting a primary key.

    *fatkodima*

*   Fix Mysql2Adapter support for prepared statements

    Using prepared statements with MySQL could result in a `NoMethodError` exception.

    *Jean Boussier*, *Leo Arnold*, *zzak*

*   Fix parsing of SQLite foreign key names when they contain non-ASCII characters

    *Zacharias Knudsen*

*   Fix parsing of MySQL 8.0.16+ CHECK constraints when they contain new lines.

    *Steve Hill*

*   Ensure normalized attribute queries use `IS NULL` consistently for `nil` and normalized `nil` values.

    *Joshua Young*

*   Fix `sum` when performing a grouped calculation.

    `User.group(:friendly).sum` no longer worked. This is fixed.

    *Edouard Chin*

*   Restore back the ability to pass only database name to `DATABASE_URL`.

    *fatkodima*


## Rails 8.0.0.1 (December 10, 2024) ##

*   No changes.


## Rails 8.0.0 (November 07, 2024) ##

*   Fix support for `query_cache: false` in `database.yml`.

    `query_cache: false` would no longer entirely disable the Active Record query cache.

    *zzak*


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   NULLS NOT DISTINCT works with UNIQUE CONSTRAINT as well as UNIQUE INDEX.

    *Ryuta Kamizono*

*   The `db:prepare` task no longer loads seeds when a non-primary database is created.

    Previously, the `db:prepare` task would load seeds whenever a new database
    is created, leading to potential loss of data if a database is added to an
    existing environment.

    Introduces a new database config property `seeds` to control whether seeds
    are loaded during `db:prepare` which defaults to `true` for primary database
    configs and `false` otherwise.

    Fixes #53348.

    *Mike Dalessio*

*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

*   Fix strict loading propagation even if statement cache is not used.

    *Ryuta Kamizono*

*   Allow `rename_enum` accepts two from/to name arguments as `rename_table` does so.

    *Ryuta Kamizono*


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   Remove deprecated support to setting `ENV["SCHEMA_CACHE"]`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing a database name to `cache_dump_filename`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::ConnectionPool#connection`.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_record.sqlite3_deprecated_warning`.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_record.warn_on_records_fetched_greater_than`.

    *Rafael Mendonça França*

*   Remove deprecated support for defining `enum` with keyword arguments.

    *Rafael Mendonça França*

*   Remove deprecated support to finding database adapters that aren't registered to Active Record.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_record.allow_deprecated_singular_associations_name`.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_record.commit_transaction_on_non_local_return`.

    *Rafael Mendonça França*

*   Fix incorrect SQL query when passing an empty hash to `ActiveRecord::Base.insert`.

    *David Stosik*

*   Allow to save records with polymorphic join tables that have `inverse_of`
    specified.

    *Markus Doits*

*   Fix association scopes applying on the incorrect join when using a polymorphic `has_many through:`.

    *Joshua Young*

*   Allow `ActiveRecord::Base#pluck` to accept hash arguments with symbol and string values.

    ```ruby
    Post.joins(:comments).pluck(:id, comments: :id)
    Post.joins(:comments).pluck("id", "comments" => "id")
    ```

    *Joshua Young*

*   Make Float distinguish between `float4` and `float8` in PostgreSQL.

    Fixes #52742

    *Ryota Kitazawa*, *Takayuki Nagatomi*


## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Allow `drop_table` to accept an array of table names.

    This will let you to drop multiple tables in a single call.

    ```ruby
    ActiveRecord::Base.lease_connection.drop_table(:users, :posts)
    ```

    *Gabriel Sobrinho*

*   Add support for PostgreSQL `IF NOT EXISTS` via the `:if_not_exists` option
    on the `add_enum_value` method.

    *Ariel Rzezak*

*   When running `db:migrate` on a fresh database, load the databases schemas before running migrations.

    *Andrew Novoselac*, *Marek Kasztelnik*

*   Fix an issue where `.left_outer_joins` used with multiple associations that have
    the same child association but different parents does not join all parents.

    Previously, using `.left_outer_joins` with the same child association would only join one of the parents.

    Now it will correctly join both parents.

    Fixes #41498.

    *Garrett Blehm*

*   Deprecate `unsigned_float` and `unsigned_decimal` short-hand column methods.

    As of MySQL 8.0.17, the UNSIGNED attribute is deprecated for columns of type FLOAT, DOUBLE,
    and DECIMAL. Consider using a simple CHECK constraint instead for such columns.

    https://dev.mysql.com/doc/refman/8.0/en/numeric-type-syntax.html

    *Ryuta Kamizono*

*   Drop MySQL 5.5 support.

    MySQL 5.5 is the only version that does not support datetime with precision,
    which we have supported in the core. Now we support MySQL 5.6.4 or later, which
    is the first version to support datetime with precision.

    *Ryuta Kamizono*

*   Make Active Record asynchronous queries compatible with transactional fixtures.

    Previously transactional fixtures would disable asynchronous queries, because transactional
    fixtures impose all queries use the same connection.

    Now asynchronous queries will use the connection pinned by transactional fixtures, and behave
    much closer to production.

    *Jean Boussier*

*   Deserialize binary data before decrypting

    This ensures that we call `PG::Connection.unescape_bytea` on PostgreSQL before decryption.

    *Donal McBreen*

*   Ensure `ActiveRecord::Encryption.config` is always ready before access.

    Previously, `ActiveRecord::Encryption` configuration was deferred until `ActiveRecord::Base`
    was loaded. Therefore, accessing `ActiveRecord::Encryption.config` properties before
    `ActiveRecord::Base` was loaded would give incorrect results.

    `ActiveRecord::Encryption` now has its own loading hook so that its configuration is set as
    soon as needed.

    When `ActiveRecord::Base` is loaded, even lazily, it in turn triggers the loading of
    `ActiveRecord::Encryption`, thus preserving the original behavior of having its config ready
    before any use of `ActiveRecord::Base`.

    *Maxime Réty*

*   Add `TimeZoneConverter#==` method, so objects will be properly compared by
    their type, scale, limit & precision.

    Address #52699.

    *Ruy Rocha*

*   Add support for SQLite3 full-text-search and other virtual tables.

    Previously, adding sqlite3 virtual tables messed up `schema.rb`.

    Now, virtual tables can safely be added using `create_virtual_table`.

    *Zacharias Knudsen*

*   Support use of alternative database interfaces via the `database_cli` ActiveRecord configuration option.

    ```ruby
    Rails.application.configure do
      config.active_record.database_cli = { postgresql: "pgcli" }
    end
    ```

    *T S Vallender*

*   Add support for dumping table inheritance and native partitioning table definitions for PostgeSQL adapter

    *Justin Talbott*

*   Add support for `ActiveRecord::Point` type casts using `Hash` values

    This allows `ActiveRecord::Point` to be cast or serialized from a hash
    with `:x` and `:y` keys of numeric values, mirroring the functionality of
    existing casts for string and array values. Both string and symbol keys are
    supported.

    ```ruby
    class PostgresqlPoint < ActiveRecord::Base
      attribute :x, :point
      attribute :y, :point
      attribute :z, :point
    end

    val = PostgresqlPoint.new({
      x: '(12.34, -43.21)',
      y: [12.34, '-43.21'],
      z: {x: '12.34', y: -43.21}
    })
    ActiveRecord::Point.new(12.32, -43.21) == val.x == val.y == val.z
    ```

    *Stephen Drew*

*   Replace `SQLite3::Database#busy_timeout` with `#busy_handler_timeout=`.

    Provides a non-GVL-blocking, fair retry interval busy handler implementation.

    *Stephen Margheim*

*   SQLite3Adapter: Translate `SQLite3::BusyException` into `ActiveRecord::StatementTimeout`.

    *Matthew Nguyen*

*   Include schema name in `enable_extension` statements in `db/schema.rb`.

    The schema dumper will now include the schema name in generated
    `enable_extension` statements if they differ from the current schema.

    For example, if you have a migration:

    ```ruby
    enable_extension "heroku_ext.pgcrypto"
    enable_extension "pg_stat_statements"
    ```

    then the generated schema dump will also contain:

    ```ruby
    enable_extension "heroku_ext.pgcrypto"
    enable_extension "pg_stat_statements"
    ```

    *Tony Novak*

*   Fix `ActiveRecord::Encryption::EncryptedAttributeType#type` to return
    actual cast type.

    *Vasiliy Ermolovich*

*   SQLite3Adapter: Bulk insert fixtures.

    Previously one insert command was executed for each fixture, now they are
    aggregated in a single bulk insert command.

    *Lázaro Nixon*

*   PostgreSQLAdapter: Allow `disable_extension` to be called with schema-qualified name.

    For parity with `enable_extension`, the `disable_extension` method can be called with a schema-qualified
    name (e.g. `disable_extension "myschema.pgcrypto"`). Note that PostgreSQL's `DROP EXTENSION` does not
    actually take a schema name (unlike `CREATE EXTENSION`), so the resulting SQL statement will only name
    the extension, e.g. `DROP EXTENSION IF EXISTS "pgcrypto"`.

    *Tony Novak*

*   Make `create_schema` / `drop_schema` reversible in migrations.

    Previously, `create_schema` and `drop_schema` were irreversible migration operations.

    *Tony Novak*

*   Support batching using custom columns.

    ```ruby
    Product.in_batches(cursor: [:shop_id, :id]) do |relation|
      # do something with relation
    end
    ```

    *fatkodima*

*   Use SQLite `IMMEDIATE` transactions when possible.

    Transactions run against the SQLite3 adapter default to IMMEDIATE mode to improve concurrency support and avoid busy exceptions.

    *Stephen Margheim*

*   Raise specific exception when a connection is not defined.

    The new `ConnectionNotDefined` exception provides connection name, shard and role accessors indicating the details of the connection that was requested.

    *Hana Harencarova*, *Matthew Draper*

*   Delete the deprecated constant `ActiveRecord::ImmutableRelation`.

    *Xavier Noria*

*   Fix duplicate callback execution when child autosaves parent with `has_one` and `belongs_to`.

    Before, persisting a new child record with a new associated parent record would run `before_validation`,
    `after_validation`, `before_save` and `after_save` callbacks twice.

    Now, these callbacks are only executed once as expected.

    *Joshua Young*

*   `ActiveRecord::Encryption::Encryptor` now supports a `:compressor` option to customize the compression algorithm used.

    ```ruby
    module ZstdCompressor
      def self.deflate(data)
        Zstd.compress(data)
      end

      def self.inflate(data)
        Zstd.decompress(data)
      end
    end

    class User
      encrypts :name, compressor: ZstdCompressor
    end
    ```

    You disable compression by passing `compress: false`.

    ```ruby
    class User
      encrypts :name, compress: false
    end
    ```

    *heka1024*

*   Add condensed `#inspect` for `ConnectionPool`, `AbstractAdapter`, and
    `DatabaseConfig`.

    *Hartley McGuire*

*   Add `.shard_keys`, `.sharded?`, & `.connected_to_all_shards` methods.

    ```ruby
    class ShardedBase < ActiveRecord::Base
        self.abstract_class = true

        connects_to shards: {
          shard_one: { writing: :shard_one },
          shard_two: { writing: :shard_two }
        }
    end

    class ShardedModel < ShardedBase
    end

    ShardedModel.shard_keys => [:shard_one, :shard_two]
    ShardedModel.sharded? => true
    ShardedBase.connected_to_all_shards { ShardedModel.current_shard } => [:shard_one, :shard_two]
    ```

    *Nony Dutton*

*   Add a `filter` option to `in_order_of` to prioritize certain values in the sorting without filtering the results
    by these values.

    *Igor Depolli*

*   Fix an issue where the IDs reader method did not return expected results
    for preloaded associations in models using composite primary keys.

    *Jay Ang*

*   Allow to configure `strict_loading_mode` globally or within a model.

    Defaults to `:all`, can be changed to `:n_plus_one_only`.

    *Garen Torikian*

*   Add `ActiveRecord::Relation#readonly?`.

    Reflects if the relation has been marked as readonly.

    *Theodor Tonum*

*   Improve `ActiveRecord::Store` to raise a descriptive exception if the column is not either
    structured (e.g., PostgreSQL +hstore+/+json+, or MySQL +json+) or declared serializable via
    `ActiveRecord.store`.

    Previously, a `NoMethodError` would be raised when the accessor was read or written:

        NoMethodError: undefined method `accessor' for an instance of ActiveRecord::Type::Text

    Now, a descriptive `ConfigurationError` is raised:

        ActiveRecord::ConfigurationError: the column 'metadata' has not been configured as a store.
          Please make sure the column is declared serializable via 'ActiveRecord.store' or, if your
          database supports it, use a structured column type like hstore or json.

    *Mike Dalessio*

*   Fix inference of association model on nested models with the same demodularized name.

    E.g. with the following setup:

    ```ruby
    class Nested::Post < ApplicationRecord
      has_one :post, through: :other
    end
    ```

    Before, `#post` would infer the model as `Nested::Post`, but now it correctly infers `Post`.

    *Joshua Young*

*   Add public method for checking if a table is ignored by the schema cache.

    Previously, an application would need to reimplement `ignored_table?` from the schema cache class to check if a table was set to be ignored. This adds a public method to support this and updates the schema cache to use that directly.

    ```ruby
    ActiveRecord.schema_cache_ignored_tables = ["developers"]
    ActiveRecord.schema_cache_ignored_table?("developers")
    => true
    ```

    *Eileen M. Uchitelle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md) for previous changes.
