*   Allow overriding SQLite defaults from `database.yml`

    Any PRAGMA configuration set under the `pragmas` key in the configuration file take precedence over Rails' defaults, and additional PRAGMAs can be set as well.

    ```yaml
    database: storage/development.sqlite3
    timeout: 5000
    pragmas:
      journal_mode: off
      temp_store: memory
    ```

    *Stephen Margheim*

*   Remove warning message when running SQLite in production, but leave it unconfigured

    There are valid use cases for running SQLite in production, however it must be done
    with care, so instead of a warning most users won't see anyway, it's preferable to
    leave the configuration commented out to force them to think about having the database
    on a persistent volume etc.

    *Jacopo Beschi*, *Jean Boussier*

*   Add support for generated columns in SQLite3 adapter

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

    This allows to configure a connection on a UNIX socket via DATABASE_URL:

    ```
    DATABASE_URL=trilogy://does-not-matter/my_db_production?socket=/var/run/mysql.sock
    ```

    *Jean Boussier*

*   Make `assert_queries_count`, `assert_no_queries`, `assert_queries_match` and
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

*   `DatabaseConfigurations#configs_for` can accept a symbol in the `name` parameter.

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

    With the `attributes_for_inspect` set to `:all`, `inspect` will list all the record's attributes.

    ```ruby
    Post.attributes_for_inspect = :all
    Post.first.inspect #=> "#<Post id: 1, title: "Hello, World!", published_at: "2023-10-23 14:28:11 +0000">"
    ```

    In development and test mode, `attributes_for_inspect` will be set to `:all` by default.

    You can also call `full_inspect` to get an inspection with all the attributes.

    The attributes in `attribute_for_inspect` will also be used for `pretty_print`.

    *Andrew Novoselac*

*   Don't mark Float::INFINITY as changed when reassigning it

    When saving a record with a float infinite value, it shouldn't mark as changed

    *Maicol Bentancor*

*   Support `RETURNING` clause for MariaDB

    *fatkodima*, *Nikolay Kondratyev*

*   The SQLite3 adapter now implements the `supports_deferrable_constraints?` contract

    Allows foreign keys to be deferred by adding the `:deferrable` key to the `foreign_key` options.

    ```ruby
    add_reference :person, :alias, foreign_key: { deferrable: :deferred }
    add_reference :alias, :person, foreign_key: { deferrable: :deferred }
    ```

    *Stephen Margheim*

*   Add `set_constraints` helper for PostgreSQL

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

*   Include `ActiveModel::API` in `ActiveRecord::Base`

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

*   Add `nulls_last` and working `desc.nulls_first` for MySQL.

    *Tristan Fellows*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
