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

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
