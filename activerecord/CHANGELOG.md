*   Expose a generic fixture accessor for fixture names that may conflict with Minitest

    ```ruby
    assert_equal "Ruby on Rails", web_sites(:rubyonrails).name
    assert_equal "Ruby on Rails", fixture(:web_sites, :rubyonrails).name
    ```

    *Jean Boussier*

*   Using `Model.query_constraints` with a single non-primary-key column used to raise as expected, but with an
    incorrect error message. This has been fixed to raise with a more appropriate error message.

    *Joshua Young*

*   Fix `has_one` association autosave setting the foreign key attribute when it is unchanged.

    This behaviour is also inconsistent with autosaving `belongs_to` and can have unintended side effects like raising
    an `ActiveRecord::ReadOnlyAttributeError` when the foreign key attribute is marked as read-only.

    *Joshua Young*

*   Remove deprecated behavior that would rollback a transaction block when exited using `return`, `break` or `throw`.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.active_record.commit_transaction_on_non_local_return`.

    *Rafael Mendonça França*

*   Remove deprecated support to pass `rewhere` to `ActiveRecord::Relation#merge`.

    *Rafael Mendonça França*

*   Remove deprecated support to pass `deferrable: true` to `add_foreign_key`.

    *Rafael Mendonça França*

*   Remove deprecated support to quote `ActiveSupport::Duration`.

    *Rafael Mendonça França*

*   Remove deprecated `#quote_bound_value`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::ConnectionPool#connection_klass`.

    *Rafael Mendonça França*

*   Remove deprecated support to apply `#connection_pool_list`, `#active_connections?`, `#clear_active_connections!`,
    `#clear_reloadable_connections!`, `#clear_all_connections!` and `#flush_idle_connections!` to the connections pools
    for the current role when the `role` argument isn't provided.

    *Rafael Mendonça França*

*   Remove deprecated `#all_connection_pools`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SchemaCache#data_sources`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SchemaCache.load_from`.

    *Rafael Mendonça França*

*   Remove deprecated `#all_foreign_keys_valid?` from database adapters.

    *Rafael Mendonça França*

*   Remove deprecated support to passing coder and class as second argument to `serialize`.

    *Rafael Mendonça França*

*   Remove deprecated support to `ActiveRecord::Base#read_attribute(:id)` to return the custom primary key value.

    *Rafael Mendonça França*

*   Remove deprecated `TestFixtures.fixture_path`.

    *Rafael Mendonça França*

*   Remove deprecated behavior to support referring to a singular association by its plural name.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.active_record.allow_deprecated_singular_associations_name`

    *Rafael Mendonça França*

*   Remove deprecated support to passing `SchemaMigration` and `InternalMetadata` classes as arguments to
    `ActiveRecord::MigrationContext`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Migration.check_pending` method.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::LogSubscriber.runtime` method.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::LogSubscriber.runtime=` method.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::LogSubscriber.reset_runtime` method.

    *Rafael Mendonça França*

*   Remove deprecated support to define `explain` in the connection adapter with 2 arguments.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ActiveJobRequiredError`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.clear_active_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.clear_reloadable_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.clear_all_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.flush_idle_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `name` argument from `ActiveRecord::Base.remove_connection`.

    *Rafael Mendonça França*

*   Remove deprecated support to call `alias_attribute` with non-existent attribute names.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.application.config.active_record.suppress_multiple_database_warning`.

    *Rafael Mendonça França*

*   Add ActiveRecord::Encryption::MessagePackMessageSerializer

    Serialize data to the MessagePack format, for efficient storage in binary columns.

    The binary encoding requires around 30% less space than the base64 encoding
    used by the default serializer.

    *Donal McBreen*

*   Add support for encrypting binary columns

    Ensure encryption and decryption pass `Type::Binary::Data` around for binary data.

    Previously encrypting binary columns with the `ActiveRecord::Encryption::MessageSerializer`
    incidentally worked for MySQL and SQLite, but not PostgreSQL.

    *Donal McBreen*

*   Deprecated `ENV["SCHEMA_CACHE"]` in favor of `schema_cache_path` in the database configuration.

    *Rafael Mendonça França*

*   Add `ActiveRecord::Base.with_connection` as a shortcut for leasing a connection for a short duration.

    The leased connection is yielded, and for the duration of the block, any call to `ActiveRecord::Base.connection`
    will yield that same connection.

    This is useful to perform a few database operations without causing a connection to be leased for the
    entire duration of the request or job.

    *Jean Boussier*

*   Deprecate `config.active_record.warn_on_records_fetched_greater_than` now that `sql.active_record`
    notification includes `:row_count` field.

    *Jason Nochlin*

*   The fix ensures that the association is joined using the appropriate join type
    (either inner join or left outer join) based on the existing joins in the scope.

    This prevents unintentional overrides of existing join types and ensures consistency in the generated SQL queries.

    Example:



    ```ruby
    # `associated` will use `LEFT JOIN` instead of using `JOIN`
    Post.left_joins(:author).where.associated(:author)
    ```

    *Saleh Alhaddad*

*   Fix an issue where `ActiveRecord::Encryption` configurations are not ready before the loading
    of Active Record models, when an application is eager loaded. As a result, encrypted attributes
    could be misconfigured in some cases.

    *Maxime Réty*

*   Deprecate defining an `enum` with keyword arguments.

    ```ruby
    class Function > ApplicationRecord
      # BAD
      enum color: [:red, :blue],
           type: [:instance, :class]

      # GOOD
      enum :color, [:red, :blue]
      enum :type, [:instance, :class]
    end
    ```

    *Hartley McGuire*

*   Add `active_record.config.validate_migration_timestamps` option for validating migration timestamps.

    When set, validates that the timestamp prefix for a migration is no more than a day ahead of
    the timestamp associated with the current time. This is designed to prevent migrations prefixes
    from being hand-edited to future timestamps, which impacts migration generation and other
    migration commands.

    *Adrianna Chang*

*   Properly synchronize `Mysql2Adapter#active?` and `TrilogyAdapter#active?`

    As well as `disconnect!` and `verify!`.

    This generally isn't a big problem as connections must not be shared between
    threads, but is required when running transactional tests or system tests
    and could lead to a SEGV.

    *Jean Boussier*

*   Support `:source_location` tag option for query log tags

    ```ruby
    config.active_record.query_log_tags << :source_location
    ```

    Calculating the caller location is a costly operation and should be used primarily in development
    (note, there is also a `config.active_record.verbose_query_logs` that serves the same purpose)
    or occasionally on production for debugging purposes.

    *fatkodima*

*   Add an option to `ActiveRecord::Encryption::Encryptor` to disable compression

    Allow compression to be disabled by setting `compress: false`

    ```ruby
      class User
        encrypts :name, encryptor: ActiveRecord::Encryption::Encryptor.new(compress: false)
      end
    ```

    *Donal McBreen*

*   Deprecate passing strings to `ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename`.

    A `ActiveRecord::DatabaseConfigurations::DatabaseConfig` object should be passed instead.

    *Rafael Mendonça França*

*   Add row_count field to sql.active_record notification

    This field returns the amount of rows returned by the query that emitted the notification.

    This metric is useful in cases where one wants to detect queries with big result sets.

    *Marvin Bitterlich*

*   Consistently raise an `ArgumentError` when passing an invalid argument to a nested attributes association writer.

    Previously, this would only raise on collection associations and produce a generic error on singular associations.

    Now, it will raise on both collection and singular associations.

    *Joshua Young*

*   Fix single quote escapes on default generated MySQL columns

    MySQL 5.7.5+ supports generated columns, which can be used to create a column that is computed from an expression.

    Previously, the schema dump would output a string with double escapes for generated columns with single quotes in the default expression.

    This would result in issues when importing the schema on a fresh instance of a MySQL database.

    Now, the string will not be escaped and will be valid Ruby upon importing of the schema.

    *Yash Kapadia*

*   Fix Migrations with versions older than 7.1 validating options given to
    `add_reference` and `t.references`.

    *Hartley McGuire*

*   Add `<role>_types` class method to `ActiveRecord::DelegatedType` so that the delegated types can be instrospected

    *JP Rosevear*

*   Make `schema_dump`, `query_cache`, `replica` and `database_tasks` configurable via `DATABASE_URL`

    This wouldn't always work previously because boolean values would be interpreted as strings.

    e.g. `DATABASE_URL=postgres://localhost/foo?schema_dump=false` now properly disable dumping the schema
    cache.

    *Mike Coutermarsh*, *Jean Boussier*

*   Introduce `ActiveRecord::Transactions::ClassMethods#set_callback`

     It is identical to `ActiveSupport::Callbacks::ClassMethods#set_callback`
     but with support for `after_commit` and `after_rollback` callback options.

    *Joshua Young*

*   Make `ActiveRecord::Encryption::Encryptor` agnostic of the serialization format used for encrypted data.

    Previously, the encryptor instance only allowed an encrypted value serialized as a `String` to be passed to the message serializer.

    Now, the encryptor lets the configured `message_serializer` decide which types of serialized encrypted values are supported. A custom serialiser is therefore allowed to serialize `ActiveRecord::Encryption::Message` objects using a type other than `String`.

    The default `ActiveRecord::Encryption::MessageSerializer` already ensures that only `String` objects are passed for deserialization.

    *Maxime Réty*

*   Fix `encrypted_attribute?` to take into account context properties passed to `encrypts`.

    *Maxime Réty*

*   The object returned by `explain` now responds to `pluck`, `first`,
    `last`, `average`, `count`, `maximum`, `minimum`, and `sum`. Those
    new methods run `EXPLAIN` on the corresponding queries:

    ```ruby
    User.all.explain.count
    # EXPLAIN SELECT COUNT(*) FROM `users`
    # ...

    User.all.explain.maximum(:id)
    # EXPLAIN SELECT MAX(`users`.`id`) FROM `users`
    # ...
    ```

    *Petrik de Heus*

*   Fixes an issue where `validates_associated` `:on`  option wasn't respected
    when validating associated records.

    *Austen Madden*, *Alex Ghiculescu*, *Rafał Brize*

*   Allow overriding SQLite defaults from `database.yml`.

    Any PRAGMA configuration set under the `pragmas` key in the configuration
    file takes precedence over Rails' defaults, and additional PRAGMAs can be
    set as well.

    ```yaml
    database: storage/development.sqlite3
    timeout: 5000
    pragmas:
      journal_mode: off
      temp_store: memory
    ```

    *Stephen Margheim*

*   Remove warning message when running SQLite in production, but leave it unconfigured.

    There are valid use cases for running SQLite in production. However, it must be done
    with care, so instead of a warning most users won't see anyway, it's preferable to
    leave the configuration commented out to force them to think about having the database
    on a persistent volume etc.

    *Jacopo Beschi*, *Jean Boussier*

*   Add support for generated columns to the SQLite3 adapter.

    Generated columns (both stored and dynamic) are supported since version 3.31.0 of SQLite.
    This adds support for those to the SQLite3 adapter.

    ```ruby
    create_table :users do |t|
      t.string :name
      t.virtual :name_upper, type: :string, as: 'UPPER(name)'
      t.virtual :name_lower, type: :string, as: 'LOWER(name)', stored: true
    end
    ```

    *Stephen Margheim*

*   TrilogyAdapter: ignore `host` if `socket` parameter is set.

    This allows to configure a connection on a UNIX socket via `DATABASE_URL`:

    ```
    DATABASE_URL=trilogy://does-not-matter/my_db_production?socket=/var/run/mysql.sock
    ```

    *Jean Boussier*

*   Make `assert_queries_count`, `assert_no_queries`, `assert_queries_match`, and
    `assert_no_queries_match` assertions public.

    To assert the expected number of queries are made, Rails internally uses `assert_queries_count` and
    `assert_no_queries`. To assert that specific SQL queries are made, `assert_queries_match` and
    `assert_no_queries_match` are used. These assertions can now be used in applications as well.

    ```ruby
    class ArticleTest < ActiveSupport::TestCase
      test "queries are made" do
        assert_queries_count(1) { Article.first }
      end

      test "creates a foreign key" do
        assert_queries_match(/ADD FOREIGN KEY/i, include_schema: true) do
          @connection.add_foreign_key(:comments, :posts)
        end
      end
    end
    ```

    *Petrik de Heus*, *fatkodima*

*   Fix `has_secure_token` calls the setter method on initialize.

    *Abeid Ahmed*

*   When using a `DATABASE_URL`, allow for a configuration to map the protocol in the URL to a specific database
    adapter. This allows decoupling the adapter the application chooses to use from the database connection details
    set in the deployment environment.

    ```ruby
    # ENV['DATABASE_URL'] = "mysql://localhost/example_database"
    config.active_record.protocol_adapters.mysql = "trilogy"
    # will connect to MySQL using the trilogy adapter
    ```

    *Jean Boussier*, *Kevin McPhillips*

*   In cases where MySQL returns `warning_count` greater than zero, but returns no warnings when
    the `SHOW WARNINGS` query is executed, `ActiveRecord.db_warnings_action` proc will still be
    called with a generic warning message rather than silently ignoring the warning(s).

    *Kevin McPhillips*

*   `DatabaseConfigurations#configs_for` accepts a symbol in the `name` parameter.

    *Andrew Novoselac*

*   Fix `where(field: values)` queries when `field` is a serialized attribute
    (for example, when `field` uses `ActiveRecord::Base.serialize` or is a JSON
    column).

    *João Alves*

*   Make the output of `ActiveRecord::Core#inspect` configurable.

    By default, calling `inspect` on a record will yield a formatted string including just the `id`.

    ```ruby
    Post.first.inspect #=> "#<Post id: 1>"
    ```

    The attributes to be included in the output of `inspect` can be configured with
    `ActiveRecord::Core#attributes_for_inspect`.

    ```ruby
    Post.attributes_for_inspect = [:id, :title]
    Post.first.inspect #=> "#<Post id: 1, title: "Hello, World!">"
    ```

    With `attributes_for_inspect` set to `:all`, `inspect` will list all the record's attributes.

    ```ruby
    Post.attributes_for_inspect = :all
    Post.first.inspect #=> "#<Post id: 1, title: "Hello, World!", published_at: "2023-10-23 14:28:11 +0000">"
    ```

    In `development` and `test` mode, `attributes_for_inspect` will be set to `:all` by default.

    You can also call `full_inspect` to get an inspection with all the attributes.

    The attributes in `attribute_for_inspect` will also be used for `pretty_print`.

    *Andrew Novoselac*

*   Don't mark attributes as changed when reassigned to `Float::INFINITY` or
    `-Float::INFINITY`.

    *Maicol Bentancor*

*   Support the `RETURNING` clause for MariaDB.

    *fatkodima*, *Nikolay Kondratyev*

*   The SQLite3 adapter now implements the `supports_deferrable_constraints?` contract.

    Allows foreign keys to be deferred by adding the `:deferrable` key to the `foreign_key` options.

    ```ruby
    add_reference :person, :alias, foreign_key: { deferrable: :deferred }
    add_reference :alias, :person, foreign_key: { deferrable: :deferred }
    ```

    *Stephen Margheim*

*   Add the `set_constraints` helper to PostgreSQL connections.

    ```ruby
    Post.create!(user_id: -1) # => ActiveRecord::InvalidForeignKey

    Post.transaction do
      Post.connection.set_constraints(:deferred)
      p = Post.create!(user_id: -1)
      u = User.create!
      p.user = u
      p.save!
    end
    ```

    *Cody Cutrer*

*   Include `ActiveModel::API` in `ActiveRecord::Base`.

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

*   Add `nulls_last` and working `desc.nulls_first` for MySQL.

    *Tristan Fellows*

*   Allow for more complex hash arguments for `order` which mimics `where` in `ActiveRecord::Relation`.

    ```ruby
    Topic.includes(:posts).order(posts: { created_at: :desc })
    ```

    *Myles Boone*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
