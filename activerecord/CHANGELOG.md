*   Deprecate quoting `ActiveSupport::Duration` as an integer

    Using ActiveSupport::Duration as an interpolated bind parameter in a SQL
    string template is deprecated. To avoid this warning, you should explicitly
    convert the duration to a more specific database type. For example, if you
    want to use a duration as an integer number of seconds:
    ```
    Record.where("duration = ?", 1.hour.to_i)
    ```
    If you want to use a duration as an ISO 8601 string:
    ```
    Record.where("duration = ?", 1.hour.iso8601)
    ```

    *Aram Greenman*

*   Allow `QueryMethods#in_order_of` to order by a string column name.

    ```ruby
    Post.in_order_of("id", [4,2,3,1]).to_a
    Post.joins(:author).in_order_of("authors.name", ["Bob", "Anna", "John"]).to_a
    ```

    *Igor Kasyanchuk*

*   Move `ActiveRecord::SchemaMigration` to an independent object.

    `ActiveRecord::SchemaMigration` no longer inherits from `ActiveRecord::Base` and is now an independent object that should be instantiated with a `connection`. This class is private and should not be used by applications directly. If you want to interact with the schema migrations table, please access it on the connection directly, for example: `ActiveRecord::Base.connection.schema_migration`.

    *Eileen M. Uchitelle*

*   Deprecate `all_connection_pools` and make `connection_pool_list` more explicit.

    Following on #45924 `all_connection_pools` is now deprecated. `connection_pool_list` will either take an explicit role or applications can opt into the new behavior by passing `:all`.

    *Eileen M. Uchitelle*

*   Fix connection handler methods to operate on all pools.

    `active_connections?`, `clear_active_connections!`, `clear_reloadable_connections!`, `clear_all_connections!`, and `flush_idle_connections!` now operate on all pools by default. Previously they would default to using the `current_role` or `:writing` role unless specified.

    *Eileen M. Uchitelle*

*   Allow ActiveRecord::QueryMethods#select to receive hash values.

    Currently, `select` might receive only raw sql and symbols to define columns and aliases to select.

    With this change we can provide `hash` as argument, for example:

    ```ruby
    Post.joins(:comments).select(posts: [:id, :title, :created_at], comments: [:id, :body, :author_id])
    #=> "SELECT \"posts\".\"id\", \"posts\".\"title\", \"posts\".\"created_at\", \"comments\".\"id\", \"comments\".\"body\", \"comments\".\"author_id\"
    #   FROM \"posts\" INNER JOIN \"comments\" ON \"comments\".\"post_id\" = \"posts\".\"id\""

    Post.joins(:comments).select(posts: { id: :post_id, title: :post_title }, comments: { id: :comment_id, body: :comment_body })
    #=> "SELECT posts.id as post_id, posts.title as post_title, comments.id as comment_id, comments.body as comment_body
    #    FROM \"posts\" INNER JOIN \"comments\" ON \"comments\".\"post_id\" = \"posts\".\"id\""
    ```
    *Oleksandr Holubenko*, *Josef Šimánek*, *Jean Boussier*

*   Adapts virtual attributes on `ActiveRecord::Persistence#becomes`.

    When source and target classes have a different set of attributes adapts
    attributes such that the extra attributes from target are added.

    ```ruby
    class Person < ApplicationRecord
    end

    class WebUser < Person
      attribute :is_admin, :boolean
      after_initialize :set_admin

      def set_admin
        write_attribute(:is_admin, email =~ /@ourcompany\.com$/)
      end
    end

    person = Person.find_by(email: "email@ourcompany.com")
    person.respond_to? :is_admin
    # => false
    person.becomes(WebUser).is_admin?
    # => true
    ```

    *Jacopo Beschi*, *Sampson Crowley*

*   Fix `ActiveRecord::QueryMethods#in_order_of` to include `nil`s, to match the
    behavior of `Enumerable#in_order_of`.

    For example, `Post.in_order_of(:title, [nil, "foo"])` will now include posts
    with `nil` titles, the same as `Post.all.to_a.in_order_of(:title, [nil, "foo"])`.

    *fatkodima*

*   Optimize `add_timestamps` to use a single SQL statement.

    ```ruby
    add_timestamps :my_table
    ```

    Now results in the following SQL:

    ```sql
    ALTER TABLE "my_table" ADD COLUMN "created_at" datetime(6) NOT NULL, ADD COLUMN "updated_at" datetime(6) NOT NULL
    ```

    *Iliana Hadzhiatanasova*

*   Add `drop_enum` migration command for PostgreSQL

    This does the inverse of `create_enum`. Before dropping an enum, ensure you have
    dropped columns that depend on it.

    *Alex Ghiculescu*

*   Adds support for `if_exists` option when removing a check constraint.

    The `remove_check_constraint` method now accepts an `if_exists` option. If set
    to true an error won't be raised if the check constraint doesn't exist.

    *Margaret Parsa* and *Aditya Bhutani*

*   `find_or_create_by` now try to find a second time if it hits a unicity constraint.

    `find_or_create_by` always has been inherently racy, either creating multiple
    duplicate records or failing with `ActiveRecord::RecordNotUnique` depending on
    whether a proper unicity constraint was set.

    `create_or_find_by` was introduced for this use case, however it's quite wasteful
    when the record is expected to exist most of the time, as INSERT require to send
    more data than SELECT and require more work from the database. Also on some
    databases it can actually consume a primary key increment which is undesirable.

    So for case where most of the time the record is expected to exist, `find_or_create_by`
    can be made race-condition free by re-trying the `find` if the `create` failed
    with `ActiveRecord::RecordNotUnique`. This assumes that the table has the proper
    unicity constraints, if not, `find_or_create_by` will still lead to duplicated records.

    *Jean Boussier*, *Alex Kitchens*

*   Introduce a simpler constructor API for ActiveRecord database adapters.

    Previously the adapter had to know how to build a new raw connection to
    support reconnect, but also expected to be passed an initial already-
    established connection.

    When manually creating an adapter instance, it will now accept a single
    config hash, and only establish the real connection on demand.

    *Matthew Draper*

*   Avoid redundant `SELECT 1` connection-validation query during DB pool
    checkout when possible.

    If the first query run during a request is known to be idempotent, it can be
    used directly to validate the connection, saving a network round-trip.

    *Matthew Draper*

*   Automatically reconnect broken database connections when safe, even
    mid-request.

    When an error occurs while attempting to run a known-idempotent query, and
    not inside a transaction, it is safe to immediately reconnect to the
    database server and try again, so this is now the default behavior.

    This new default should always be safe -- to support that, it's consciously
    conservative about which queries are considered idempotent -- but if
    necessary it can be disabled by setting the `connection_retries` connection
    option to `0`.

    *Matthew Draper*

*   Avoid removing a PostgreSQL extension when there are dependent objects.

    Previously, removing an extension also implicitly removed dependent objects. Now, this will raise an error.

    You can force removing the extension:

    ```ruby
    disable_extension :citext, force: :cascade
    ```

    Fixes #29091.

    *fatkodima*

*   Allow nested functions as safe SQL string

    *Michael Siegfried*

*   Allow `destroy_association_async_job=` to be configured with a class string instead of a constant.

    Defers an autoloading dependency between `ActiveRecord::Base` and `ActiveJob::Base`
    and moves the configuration of `ActiveRecord::DestroyAssociationAsyncJob`
    from ActiveJob to ActiveRecord.

    Deprecates `ActiveRecord::ActiveJobRequiredError` and now raises a `NameError`
    if the job class is unloadable or an `ActiveRecord::ConfigurationError` if
    `dependent: :destroy_async` is declared on an association but there is no job
    class configured.

    *Ben Sheldon*

*   Fix `ActiveRecord::Store` to serialize as a regular Hash

    Previously it would serialize as an `ActiveSupport::HashWithIndifferentAccess`
    which is wasteful and cause problem with YAML safe_load.

    *Jean Boussier*

*   Add `timestamptz` as a time zone aware type for PostgreSQL

    This is required for correctly parsing `timestamp with time zone` values in your database.

    If you don't want this, you can opt out by adding this initializer:

    ```ruby
    ActiveRecord::Base.time_zone_aware_types -= [:timestamptz]
    ```

    *Alex Ghiculescu*

*   Add new `ActiveRecord::Base::generates_token_for` API.

    Currently, `signed_id` fulfills the role of generating tokens for e.g.
    resetting a password.  However, signed IDs cannot reflect record state, so
    if a token is intended to be single-use, it must be tracked in a database at
    least until it expires.

    With `generates_token_for`, a token can embed data from a record.  When
    using the token to fetch the record, the data from the token and the data
    from the record will be compared.  If the two do not match, the token will
    be treated as invalid, the same as if it had expired.  For example:

    ```ruby
    class User < ActiveRecord::Base
      has_secure_password

      generates_token_for :password_reset, expires_in: 15.minutes do
        # A password's BCrypt salt changes when the password is updated.
        # By embedding (part of) the salt in a token, the token will
        # expire when the password is updated.
        BCrypt::Password.new(password_digest).salt[-10..]
      end
    end

    user = User.first
    token = user.generate_token_for(:password_reset)

    User.find_by_token_for(:password_reset, token) # => user

    user.update!(password: "new password")
    User.find_by_token_for(:password_reset, token) # => nil
    ```

    *Jonathan Hefner*

*   Optimize Active Record batching for whole table iterations.

    Previously, `in_batches` got all the ids and constructed an `IN`-based query for each batch.
    When iterating over the whole tables, this approach is not optimal as it loads unneeded ids and
    `IN` queries with lots of items are slow.

    Now, whole table iterations use range iteration (`id >= x AND id <= y`) by default which can make iteration
    several times faster. E.g., tested on a PostgreSQL table with 10 million records: querying (`253s` vs `30s`),
    updating (`288s` vs `124s`), deleting (`268s` vs `83s`).

    Only whole table iterations use this style of iteration by default. You can disable this behavior by passing `use_ranges: false`.
    If you iterate over the table and the only condition is, e.g., `archived_at: nil` (and only a tiny fraction
    of the records are archived), it makes sense to opt in to this approach:

    ```ruby
    Project.where(archived_at: nil).in_batches(use_ranges: true) do |relation|
      # do something
    end
    ```

    See #45414 for more details.

    *fatkodima*

*   `.with` query method added. Construct common table expressions with ease and get `ActiveRecord::Relation` back.

    ```ruby
    Post.with(posts_with_comments: Post.where("comments_count > ?", 0))
    # => ActiveRecord::Relation
    # WITH posts_with_comments AS (SELECT * FROM posts WHERE (comments_count > 0)) SELECT * FROM posts
    ```

    *Vlado Cingel*

*   Don't establish a new connection if an identical pool exists already.

    Previously, if `establish_connection` was called on a class that already had an established connection, the existing connection would be removed regardless of whether it was the same config. Now if a pool is found with the same values as the new connection, the existing connection will be returned instead of creating a new one.

    This has a slight change in behavior if application code is depending on a new connection being established regardless of whether it's identical to an existing connection. If the old behavior is desirable, applications should call `ActiveRecord::Base#remove_connection` before establishing a new one. Calling `establish_connection` with a different config works the same way as it did previously.

    *Eileen M. Uchitelle*

*   Update `db:prepare` task to load schema when an uninitialized database exists, and dump schema after migrations.

    *Ben Sheldon*

*   Fix supporting timezone awareness for `tsrange` and `tstzrange` array columns.

    ```ruby
    # In database migrations
    add_column :shops, :open_hours, :tsrange, array: true
    # In app config
    ActiveRecord::Base.time_zone_aware_types += [:tsrange]
    # In the code times are properly converted to app time zone
    Shop.create!(open_hours: [Time.current..8.hour.from_now])
    ```

    *Wojciech Wnętrzak*

*   Introduce strategy pattern for executing migrations.

    By default, migrations will use a strategy object that delegates the method
    to the connection adapter. Consumers can implement custom strategy objects
    to change how their migrations run.

    *Adrianna Chang*

*   Add adapter option disallowing foreign keys

    This adds a new option to be added to `database.yml` which enables skipping
    foreign key constraints usage even if the underlying database supports them.

    Usage:
    ```yaml
    development:
        <<: *default
        database: db/development.sqlite3
        foreign_keys: false
    ```

    *Paulo Barros*

*   Add configurable deprecation warning for singular associations

    This adds a deprecation warning when using the plural name of a singular associations in `where`.
    It is possible to opt into the new more performant behavior with `config.active_record.allow_deprecated_singular_associations_name = false`

    *Adam Hess*

*   Run transactional callbacks on the freshest instance to save a given
    record within a transaction.

    When multiple Active Record instances change the same record within a
    transaction, Rails runs `after_commit` or `after_rollback` callbacks for
    only one of them. `config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction`
    was added to specify how Rails chooses which instance receives the
    callbacks. The framework defaults were changed to use the new logic.

    When `config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction`
    is `true`, transactional callbacks are run on the first instance to save,
    even though its instance state may be stale.

    When it is `false`, which is the new framework default starting with version
    7.1, transactional callbacks are run on the instances with the freshest
    instance state. Those instances are chosen as follows:

    - In general, run transactional callbacks on the last instance to save a
      given record within the transaction.
    - There are two exceptions:
        - If the record is created within the transaction, then updated by
          another instance, `after_create_commit` callbacks will be run on the
          second instance. This is instead of the `after_update_commit`
          callbacks that would naively be run based on that instance’s state.
        - If the record is destroyed within the transaction, then
          `after_destroy_commit` callbacks will be fired on the last destroyed
          instance, even if a stale instance subsequently performed an update
          (which will have affected 0 rows).

    *Cameron Bothner and Mitch Vollebregt*

*   Enable strict strings mode for `SQLite3Adapter`.

    Configures SQLite with a strict strings mode, which disables double-quoted string literals.

    SQLite has some quirks around double-quoted string literals.
    It first tries to consider double-quoted strings as identifier names, but if they don't exist
    it then considers them as string literals. Because of this, typos can silently go unnoticed.
    For example, it is possible to create an index for a non existing column.
    See [SQLite documentation](https://www.sqlite.org/quirks.html#double_quoted_string_literals_are_accepted) for more details.

    If you don't want this behavior, you can disable it via:

    ```ruby
    # config/application.rb
    config.active_record.sqlite3_adapter_strict_strings_by_default = false
    ```

    Fixes #27782.

    *fatkodima*, *Jean Boussier*

*   Resolve issue where a relation cache_version could be left stale.

    Previously, when `reset` was called on a relation object it did not reset the cache_versions
    ivar. This led to a confusing situation where despite having the correct data the relation
    still reported a stale cache_version.

    Usage:

    ```ruby
    developers = Developer.all
    developers.cache_version

    Developer.update_all(updated_at: Time.now.utc + 1.second)

    developers.cache_version # Stale cache_version
    developers.reset
    developers.cache_version # Returns the current correct cache_version
    ```

    Fixes #45341.

    *Austen Madden*

*   Add support for exclusion constraints (PostgreSQL-only).

    ```ruby
    add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, name: "invoices_date_overlap"
    remove_exclusion_constraint :invoices, name: "invoices_date_overlap"
    ```

    See PostgreSQL's [`CREATE TABLE ... EXCLUDE ...`](https://www.postgresql.org/docs/12/sql-createtable.html#SQL-CREATETABLE-EXCLUDE) documentation for more on exclusion constraints.

    *Alex Robbin*

*   `change_column_null` raises if a non-boolean argument is provided

    Previously if you provided a non-boolean argument, `change_column_null` would
    treat it as truthy and make your column nullable. This could be surprising, so now
    the input must be either `true` or `false`.

    ```ruby
    change_column_null :table, :column, true # good
    change_column_null :table, :column, false # good
    change_column_null :table, :column, from: true, to: false # raises (previously this made the column nullable)
    ```

    *Alex Ghiculescu*

*   Enforce limit on table names length.

    Fixes #45130.

    *fatkodima*

*   Adjust the minimum MariaDB version for check constraints support.

    *Eddie Lebow*

*   Fix Hstore deserialize regression.

    *edsharp*

*   Add validity for PostgreSQL indexes.

    ```ruby
    connection.index_exists?(:users, :email, valid: true)
    connection.indexes(:users).select(&:valid?)
    ```

    *fatkodima*

*   Fix eager loading for models without primary keys.

    *Anmol Chopra*, *Matt Lawrence*, and *Jonathan Hefner*

*   Avoid validating a unique field if it has not changed and is backed by a unique index.

    Previously, when saving a record, Active Record will perform an extra query to check for the
    uniqueness of each attribute having a `uniqueness` validation, even if that attribute hasn't changed.
    If the database has the corresponding unique index, then this validation can never fail for persisted
    records, and we could safely skip it.

    *fatkodima*

*   Stop setting `sql_auto_is_null`

    Since version 5.5 the default has been off, we no longer have to manually turn it off.

    *Adam Hess*

*   Fix `touch` to raise an error for readonly columns.

    *fatkodima*

*   Add ability to ignore tables by regexp for SQL schema dumps.

    ```ruby
    ActiveRecord::SchemaDumper.ignore_tables = [/^_/]
    ```

    *fatkodima*

*   Avoid queries when performing calculations on contradictory relations.

    Previously calculations would make a query even when passed a
    contradiction, such as `User.where(id: []).count`. We no longer perform a
    query in that scenario.

    This applies to the following calculations: `count`, `sum`, `average`,
    `minimum` and `maximum`

    *Luan Vieira, John Hawthorn and Daniel Colson*

*   Allow using aliased attributes with `insert_all`/`upsert_all`.

    ```ruby
    class Book < ApplicationRecord
      alias_attribute :title, :name
    end

    Book.insert_all [{ title: "Remote", author_id: 1 }], returning: :title
    ```

    *fatkodima*

*   Support encrypted attributes on columns with default db values.

    This adds support for encrypted attributes defined on columns with default values.
    It will encrypt those values at creation time. Before, it would raise an
    error unless `config.active_record.encryption.support_unencrypted_data` was true.

    *Jorge Manrubia* and *Dima Fatko*

*   Allow overriding `reading_request?` in `DatabaseSelector::Resolver`

    The default implementation checks if a request is a `get?` or `head?`,
    but you can now change it to anything you like. If the method returns true,
    `Resolver#read` gets called meaning the request could be served by the
    replica database.

    *Alex Ghiculescu*

*   Remove `ActiveRecord.legacy_connection_handling`.

    *Eileen M. Uchitelle*

*   `rails db:schema:{dump,load}` now checks `ENV["SCHEMA_FORMAT"]` before config

    Since `rails db:structure:{dump,load}` was deprecated there wasn't a simple
    way to dump a schema to both SQL and Ruby formats. You can now do this with
    an environment variable. For example:

    ```
    SCHEMA_FORMAT=sql rake db:schema:dump
    ```

    *Alex Ghiculescu*

*   Fixed MariaDB default function support.

    Defaults would be written wrong in "db/schema.rb" and not work correctly
    if using `db:schema:load`. Further more the function name would be
    added as string content when saving new records.

    *kaspernj*

*   Add `active_record.destroy_association_async_batch_size` configuration

    This allows applications to specify the maximum number of records that will
    be destroyed in a single background job by the `dependent: :destroy_async`
    association option. By default, the current behavior will remain the same:
    when a parent record is destroyed, all dependent records will be destroyed
    in a single background job. If the number of dependent records is greater
    than this configuration, the records will be destroyed in multiple
    background jobs.

    *Nick Holden*

*   Fix `remove_foreign_key` with `:if_exists` option when foreign key actually exists.

    *fatkodima*

*   Remove `--no-comments` flag in structure dumps for PostgreSQL

    This broke some apps that used custom schema comments. If you don't want
    comments in your structure dump, you can use:

    ```ruby
    ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ['--no-comments']
    ```

    *Alex Ghiculescu*

*   Reduce the memory footprint of fixtures accessors.

    Until now fixtures accessors were eagerly defined using `define_method`.
    So the memory usage was directly dependent of the number of fixtures and
    test suites.

    Instead fixtures accessors are now implemented with `method_missing`,
    so they incur much less memory and CPU overhead.

    *Jean Boussier*

*   Fix `config.active_record.destroy_association_async_job` configuration

    `config.active_record.destroy_association_async_job` should allow
    applications to specify the job that will be used to destroy associated
    records in the background for `has_many` associations with the
    `dependent: :destroy_async` option. Previously, that was ignored, which
    meant the default `ActiveRecord::DestroyAssociationAsyncJob` always
    destroyed records in the background.

    *Nick Holden*

*   Fix `change_column_comment` to preserve column's AUTO_INCREMENT in the MySQL adapter

    *fatkodima*

*   Fix quoting of `ActiveSupport::Duration` and `Rational` numbers in the MySQL adapter.

    *Kevin McPhillips*

*   Allow column name with COLLATE (e.g., title COLLATE "C") as safe SQL string

    *Shugo Maeda*

*   Permit underscores in the VERSION argument to database rake tasks.

    *Eddie Lebow*

*   Reversed the order of `INSERT` statements in `structure.sql` dumps

    This should decrease the likelihood of merge conflicts. New migrations
    will now be added at the top of the list.

    For existing apps, there will be a large diff the next time `structure.sql`
    is generated.

    *Alex Ghiculescu*, *Matt Larraz*

*   Fix PG.connect keyword arguments deprecation warning on ruby 2.7

    Fixes #44307.

    *Nikita Vasilevsky*

*   Fix dropping DB connections after serialization failures and deadlocks.

    Prior to 6.1.4, serialization failures and deadlocks caused rollbacks to be
    issued for both real transactions and savepoints. This breaks MySQL which
    disallows rollbacks of savepoints following a deadlock.

    6.1.4 removed these rollbacks, for both transactions and savepoints, causing
    the DB connection to be left in an unknown state and thus discarded.

    These rollbacks are now restored, except for savepoints on MySQL.

    *Thomas Morgan*

*   Make `ActiveRecord::ConnectionPool` Fiber-safe

    When `ActiveSupport::IsolatedExecutionState.isolation_level` is set to `:fiber`,
    the connection pool now supports multiple Fibers from the same Thread checking
    out connections from the pool.

    *Alex Matchneer*

*   Add `update_attribute!` to `ActiveRecord::Persistence`

    Similar to `update_attribute`, but raises `ActiveRecord::RecordNotSaved` when a `before_*` callback throws `:abort`.

    ```ruby
    class Topic < ActiveRecord::Base
      before_save :check_title

      def check_title
        throw(:abort) if title == "abort"
      end
    end

    topic = Topic.create(title: "Test Title")
    # #=> #<Topic title: "Test Title">
    topic.update_attribute!(:title, "Another Title")
    # #=> #<Topic title: "Another Title">
    topic.update_attribute!(:title, "abort")
    # raises ActiveRecord::RecordNotSaved
    ```

    *Drew Tempelmeyer*

*   Avoid loading every record in `ActiveRecord::Relation#pretty_print`

    ```ruby
    # Before
    pp Foo.all # Loads the whole table.

    # After
    pp Foo.all # Shows 10 items and an ellipsis.
    ```

    *Ulysse Buonomo*

*   Change `QueryMethods#in_order_of` to drop records not listed in values.

    `in_order_of` now filters down to the values provided, to match the behavior of the `Enumerable` version.

    *Kevin Newton*

*   Allow named expression indexes to be revertible.

    Previously, the following code would raise an error in a reversible migration executed while rolling back, due to the index name not being used in the index removal.

    ```ruby
    add_index(:settings, "(data->'property')", using: :gin, name: :index_settings_data_property)
    ```

    Fixes #43331.

    *Oliver Günther*

*   Fix incorrect argument in PostgreSQL structure dump tasks.

    Updating the `--no-comment` argument added in Rails 7 to the correct `--no-comments` argument.

    *Alex Dent*

*   Fix migration compatibility to create SQLite references/belongs_to column as integer when migration version is 6.0.

    Reference/belongs_to in migrations with version 6.0 were creating columns as
    bigint instead of integer for the SQLite Adapter.

    *Marcelo Lauxen*

*   Add a deprecation warning when `prepared_statements` configuration is not
    set for the mysql2 adapter.

    *Thiago Araujo and Stefanni Brasil*

*   Fix `QueryMethods#in_order_of` to handle empty order list.

    ```ruby
    Post.in_order_of(:id, []).to_a
    ```

    Also more explicitly set the column as secondary order, so that any other
    value is still ordered.

    *Jean Boussier*

*   Fix quoting of column aliases generated by calculation methods.

    Since the alias is derived from the table name, we can't assume the result
    is a valid identifier.

    ```ruby
    class Test < ActiveRecord::Base
      self.table_name = '1abc'
    end
    Test.group(:id).count
    # syntax error at or near "1" (ActiveRecord::StatementInvalid)
    # LINE 1: SELECT COUNT(*) AS count_all, "1abc"."id" AS 1abc_id FROM "1...
    ```

    *Jean Boussier*

*   Add `authenticate_by` when using `has_secure_password`.

    `authenticate_by` is intended to replace code like the following, which
    returns early when a user with a matching email is not found:

    ```ruby
    User.find_by(email: "...")&.authenticate("...")
    ```

    Such code is vulnerable to timing-based enumeration attacks, wherein an
    attacker can determine if a user account with a given email exists. After
    confirming that an account exists, the attacker can try passwords associated
    with that email address from other leaked databases, in case the user
    re-used a password across multiple sites (a common practice). Additionally,
    knowing an account email address allows the attacker to attempt a targeted
    phishing ("spear phishing") attack.

    `authenticate_by` addresses the vulnerability by taking the same amount of
    time regardless of whether a user with a matching email is found:

    ```ruby
    User.authenticate_by(email: "...", password: "...")
    ```

    *Jonathan Hefner*


Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activerecord/CHANGELOG.md) for previous changes.
