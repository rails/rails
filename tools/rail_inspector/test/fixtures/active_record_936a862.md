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

    Previously, when saving a record, ActiveRecord will perform an extra query to check for the uniqueness of
    each attribute having a `uniqueness` validation, even if that attribute hasn't changed.
    If the database has the corresponding unique index, then this validation can never fail for persisted records,
    and we could safely skip it.

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
