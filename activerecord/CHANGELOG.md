## Rails 6.0.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.0.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.0.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.0.4.3 (December 14, 2021) ##

*   No changes.


## Rails 6.0.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.0.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.0.4 (June 15, 2021) ##

*   Only warn about negative enums if a positive form that would cause conflicts exists.

    Fixes #39065.

    *Alex Ghiculescu*

*   Allow the inverse of a `has_one` association that was previously autosaved to be loaded.

    Fixes #34255.

    *Steven Weber*

*   Reset statement cache for association if `table_name` is changed.

    Fixes #36453.

    *Ryuta Kamizono*

*   Type cast extra select for eager loading.

    *Ryuta Kamizono*

*   Prevent collection associations from being autosaved multiple times.

    Fixes #39173.

    *Eugene Kenny*

*   Resolve issue with insert_all unique_by option when used with expression index.

    When the `:unique_by` option of `ActiveRecord::Persistence.insert_all` and
    `ActiveRecord::Persistence.upsert_all` was used with the name of an expression index, an error
    was raised. Adding a guard around the formatting behavior for the `:unique_by` corrects this.

    Usage:

    ```ruby
    create_table :books, id: :integer, force: true do |t|
      t.column :name, :string
      t.index "lower(name)", unique: true
    end

    Book.insert_all [{ name: "MyTest" }], unique_by: :index_books_on_lower_name
    ```

    Fixes #39516.

    *Austen Madden*

*   Fix preloading for polymorphic association with custom scope.

    *Ryuta Kamizono*

*   Allow relations with different SQL comments in the `or` method.

    *Takumi Shotoku*

*   Resolve conflict between counter cache and optimistic locking.

    Bump an Active Record instance's lock version after updating its counter
    cache. This avoids raising an unnecessary `ActiveRecord::StaleObjectError`
    upon subsequent transactions by maintaining parity with the corresponding
    database record's `lock_version` column.

    Fixes #16449.

    *Aaron Lipman*

*   Fix through association with source/through scope which has joins.

    *Ryuta Kamizono*

*   Fix through association to respect source scope for includes/preload.

    *Ryuta Kamizono*

*   Fix eager load with Arel joins to maintain the original joins order.

    *Ryuta Kamizono*

*   Fix group by count with eager loading + order + limit/offset.

    *Ryuta Kamizono*

*   Fix left joins order when merging multiple left joins from different associations.

    *Ryuta Kamizono*

*   Fix index creation to preserve index comment in bulk change table on MySQL.

    *Ryuta Kamizono*

*   Change `remove_foreign_key` to not check `:validate` option if database
    doesn't support the feature.

    *Ryuta Kamizono*

*   Fix the result of aggregations to maintain duplicated "group by" fields.

    *Ryuta Kamizono*

*   Do not return duplicated records when using preload.

    *Bogdan Gusiev*


## Rails 6.0.3.7 (May 05, 2021) ##

*   No changes.


## Rails 6.0.3.6 (March 26, 2021) ##

*   No changes.


## Rails 6.0.3.5 (February 10, 2021) ##

*   Fix possible DoS vector in PostgreSQL money type

    Carefully crafted input can cause a DoS via the regular expressions used
    for validating the money format in the PostgreSQL adapter.  This patch
    fixes the regexp.

    Thanks to @dee-see from Hackerone for this patch!

    [CVE-2021-22880]

    *Aaron Patterson*


## Rails 6.0.3.4 (October 07, 2020) ##

*   No changes.


## Rails 6.0.3.3 (September 09, 2020) ##

*   No changes.


## Rails 6.0.3.2 (June 17, 2020) ##

*   No changes.


## Rails 6.0.3.1 (May 18, 2020) ##

*   No changes.


## Rails 6.0.3 (May 06, 2020) ##

*   Recommend applications don't use the `database` kwarg in `connected_to`

    The database kwarg in `connected_to` was meant to be used for one-off scripts but is often used in requests. This is really dangerous because it re-establishes a connection every time. It's deprecated in 6.1 and will be removed in 6.2 without replacement. This change soft deprecates it in 6.0 by removing documentation.

    *Eileen M. Uchitelle*

*   Fix support for PostgreSQL 11+ partitioned indexes.

    *Sebastián Palma*

*   Add support for beginless ranges, introduced in Ruby 2.7.

    *Josh Goodall*

*   Fix insert_all with enum values

    Fixes #38716.

    *Joel Blum*

*   Regexp-escape table name for MS SQL

    Add `Regexp.escape` to one method in ActiveRecord, so that table names with regular expression characters in them work as expected. Since MS SQL Server uses "[" and "]" to quote table and column names, and those characters are regular expression characters, methods like `pluck` and `select` fail in certain cases when used with the MS SQL Server adapter.

    *Larry Reid*

*   Store advisory locks on their own named connection.

    Previously advisory locks were taken out against a connection when a migration started. This works fine in single database applications but doesn't work well when migrations need to open new connections which results in the lock getting dropped.

    In order to fix this we are storing the advisory lock on a new connection with the connection specification name `AdisoryLockBase`. The caveat is that we need to maintain at least 2 connections to a database while migrations are running in order to do this.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Ensure `:reading` connections always raise if a write is attempted.

    Now Rails will raise an `ActiveRecord::ReadOnlyError` if any connection on the reading handler attempts to make a write. If your reading role needs to write you should name the role something other than `:reading`.

    *Eileen M. Uchitelle*

*   Enforce fresh ETag header after a collection's contents change by adding
    ActiveRecord::Relation#cache_key_with_version. This method will be used by
    ActionController::ConditionalGet to ensure that when collection cache versioning
    is enabled, requests using ConditionalGet don't return the same ETag header
    after a collection is modified. Fixes #38078.

    *Aaron Lipman*

*   A database URL can now contain a querystring value that contains an equal sign. This is needed to support passing PostgresSQL `options`.

     *Joshua Flanagan*

*   Retain explicit selections on the base model after applying `includes` and `joins`.

    Resolves #34889.

    *Patrick Rebsch*


## Rails 6.0.2.2 (March 19, 2020) ##

*   No changes.


## Rails 6.0.2.1 (December 18, 2019) ##

*   No changes.


## Rails 6.0.2 (December 13, 2019) ##

*   Share the same connection pool for primary and replica databases in the
    transactional tests for the same database.

    *Edouard Chin*

*   Fix the preloader when one record is fetched using `after_initialize`
    but not the entire collection.

    *Bradley Price*

*   Fix collection callbacks not terminating when `:abort` is thrown.

    *Edouard Chin*, *Ryuta Kamizono*

*   Correctly deprecate `where.not` working as NOR for relations.

    12a9664 deprecated where.not working as NOR, however
    doing a relation query like `where.not(relation: { ... })`
    wouldn't be properly deprecated and `where.not` would work as
    NAND instead.

    *Edouard Chin*

*   Fix `db:migrate` task with multiple databases to restore the connection
    to the previous database.

    The migrate task iterates and establish a connection over each db
    resulting in the last one to be used by subsequent rake tasks.
    We should reestablish a connection to the connection that was
    established before the migrate tasks was run

    *Edouard Chin*

*   Fix multi-threaded issue for `AcceptanceValidator`.

    *Ryuta Kamizono*


## Rails 6.0.1 (November 5, 2019) ##

*    Common Table Expressions are allowed on read-only connections.

     *Chris Morris*

*    New record instantiation respects `unscope`.

     *Ryuta Kamizono*

*    Fixed a case where `find_in_batches` could halt too early.

     *Takayuki Nakata*

*    Autosaved associations always perform validations when a custom validation
     context is used.

     *Tekin Suleyman*

*    `sql.active_record` notifications now include the `:connection` in
     their payloads.

     *Eugene Kenny*

*    A rollback encountered in an `after_commit` callback does not reset
     previously-committed record state.

     *Ryuta Kamizono*

*    Fixed that join order was lost when eager-loading.

     *Ryuta Kamizono*

*   `DESCRIBE` queries are allowed on read-only connections.

    *Dylan Thacker-Smith*

*   Fixed that records that had been `inspect`ed could not be marshaled.

    *Eugene Kenny*

*   The connection pool reaper thread is respawned in forked processes. This
    fixes that idle connections in forked processes wouldn't be reaped.

    *John Hawthorn*

*   The memoized result of `ActiveRecord::Relation#take` is properly cleared
    when `ActiveRecord::Relation#reset` or `ActiveRecord::Relation#reload`
    is called.

    *Anmol Arora*

*   Fixed the performance regression for `primary_keys` introduced MySQL 8.0.

    *Hiroyuki Ishii*

*   `insert`, `insert_all`, `upsert`, and `upsert_all` now clear the query cache.

    *Eugene Kenny*

*   Call `while_preventing_writes` directly from `connected_to`.

    In some cases application authors want to use the database switching middleware and make explicit calls with `connected_to`. It's possible for an app to turn off writes and not turn them back on by the time we call `connected_to(role: :writing)`.

    This change allows apps to fix this by assuming if a role is writing we want to allow writes, except in the case it's explicitly turned off.

    *Eileen M. Uchitelle*

*   Improve detection of ActiveRecord::StatementTimeout with mysql2 adapter in the edge case when the query is terminated during filesort.

    *Kir Shatrov*


## Rails 6.0.0 (August 16, 2019) ##

*   Preserve user supplied joins order as much as possible.

    Fixes #36761, #34328, #24281, #12953.

    *Ryuta Kamizono*

*   Make the DATABASE_URL env variable only affect the primary connection. Add new env variables for multiple databases.

    *John Crepezzi*, *Eileen Uchitelle*

*   Add a warning for enum elements with 'not_' prefix.

        class Foo
          enum status: [:sent, :not_sent]
        end

    *Edu Depetris*

*   Make currency symbols optional for money column type in PostgreSQL

    *Joel Schneider*


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   Add database_exists? method to connection adapters to check if a database exists.

    *Guilherme Mansur*

*   PostgreSQL: Fix GROUP BY with ORDER BY virtual count attribute.

    Fixes #36022.

    *Ryuta Kamizono*

*   Make ActiveRecord `ConnectionPool.connections` method thread-safe.

    Fixes #36465.

    *Jeff Doering*

*   Fix sqlite3 collation parsing when using decimal columns.

    *Martin R. Schuster*

*   Fix invalid schema when primary key column has a comment.

    Fixes #29966.

    *Guilherme Goettems Schneider*

*   Fix table comment also being applied to the primary key column.

    *Guilherme Goettems Schneider*

*   Fix merging left_joins to maintain its own `join_type` context.

    Fixes #36103.

    *Ryuta Kamizono*


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Add `touch` option to `has_one` association.

    *Abhay Nikam*

*   Deprecate `where.not` working as NOR and will be changed to NAND in Rails 6.1.

    ```ruby
    all = [treasures(:diamond), treasures(:sapphire), cars(:honda), treasures(:sapphire)]
    assert_equal all, PriceEstimate.all.map(&:estimate_of)
    ```

    In Rails 6.0:

    ```ruby
    sapphire = treasures(:sapphire)

    nor = all.reject { |e|
      e.estimate_of_type == sapphire.class.polymorphic_name
    }.reject { |e|
      e.estimate_of_id == sapphire.id
    }
    assert_equal [cars(:honda)], nor

    without_sapphire = PriceEstimate.where.not(
      estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id
    )
    assert_equal nor, without_sapphire.map(&:estimate_of)
    ```

    In Rails 6.1:

    ```ruby
    sapphire = treasures(:sapphire)

    nand = all - [sapphire]
    assert_equal [treasures(:diamond), cars(:honda)], nand

    without_sapphire = PriceEstimate.where.not(
      estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id
    )
    assert_equal nand, without_sapphire.map(&:estimate_of)
    ```

    *Ryuta Kamizono*

*   Fix dirty tracking after rollback.

    Fixes #15018, #30167, #33868.

    *Ryuta Kamizono*

*   Add `ActiveRecord::Relation#cache_version` to support recyclable cache keys via
    the versioned entries in `ActiveSupport::Cache`. This also means that
    `ActiveRecord::Relation#cache_key` will now return a stable key that does not
    include the max timestamp or count any more.

    NOTE: This feature is turned off by default, and `cache_key` will still return
    cache keys with timestamps until you set `ActiveRecord::Base.collection_cache_versioning = true`.
    That's the setting for all new apps on Rails 6.0+

    *Lachlan Sylvester*

*   Fix dirty tracking for `touch` to track saved changes.

    Fixes #33429.

    *Ryuta Kamzono*

*   `change_column_comment` and `change_table_comment` are invertible only if
    `to` and `from` options are specified.

    *Yoshiyuki Kinjo*

*   Don't call commit/rollback callbacks when a record isn't saved.

    Fixes #29747.

    *Ryuta Kamizono*

*   Fix circular `autosave: true` causes invalid records to be saved.

    Prior to the fix, when there was a circular series of `autosave: true`
    associations, the callback for a `has_many` association was run while
    another instance of the same callback on the same association hadn't
    finished running. When control returned to the first instance of the
    callback, the instance variable had changed, and subsequent associated
    records weren't saved correctly. Specifically, the ID field for the
    `belongs_to` corresponding to the `has_many` was `nil`.

    Fixes #28080.

    *Larry Reid*

*   Raise `ArgumentError` for invalid `:limit` and `:precision` like as other options.

    Before:

    ```ruby
    add_column :items, :attr1, :binary,   size: 10      # => ArgumentError
    add_column :items, :attr2, :decimal,  scale: 10     # => ArgumentError
    add_column :items, :attr3, :integer,  limit: 10     # => ActiveRecordError
    add_column :items, :attr4, :datetime, precision: 10 # => ActiveRecordError
    ```

    After:

    ```ruby
    add_column :items, :attr1, :binary,   size: 10      # => ArgumentError
    add_column :items, :attr2, :decimal,  scale: 10     # => ArgumentError
    add_column :items, :attr3, :integer,  limit: 10     # => ArgumentError
    add_column :items, :attr4, :datetime, precision: 10 # => ArgumentError
    ```

    *Ryuta Kamizono*

*   Association loading isn't to be affected by scoping consistently
    whether preloaded / eager loaded or not, with the exception of `unscoped`.

    Before:

    ```ruby
    Post.where("1=0").scoping do
      Comment.find(1).post                   # => nil
      Comment.preload(:post).find(1).post    # => #<Post id: 1, ...>
      Comment.eager_load(:post).find(1).post # => #<Post id: 1, ...>
    end
    ```

    After:

    ```ruby
    Post.where("1=0").scoping do
      Comment.find(1).post                   # => #<Post id: 1, ...>
      Comment.preload(:post).find(1).post    # => #<Post id: 1, ...>
      Comment.eager_load(:post).find(1).post # => #<Post id: 1, ...>
    end
    ```

    Fixes #34638, #35398.

    *Ryuta Kamizono*

*   Add `rails db:prepare` to migrate or setup a database.

    Runs `db:migrate` if the database exists or `db:setup` if it doesn't.

    *Roberto Miranda*

*   Add `after_save_commit` callback as shortcut for `after_commit :hook, on: [ :create, :update ]`.

    *DHH*

*   Assign all attributes before calling `build` to ensure the child record is visible in
    `before_add` and `after_add` callbacks for `has_many :through` associations.

    Fixes #33249.

    *Ryan H. Kerr*

*   Add `ActiveRecord::Relation#extract_associated` for extracting associated records from a relation.

    ```
    account.memberships.extract_associated(:user)
    # => Returns collection of User records
    ```

    *DHH*

*   Add `ActiveRecord::Relation#annotate` for adding SQL comments to its queries.

    For example:

    ```
    Post.where(id: 123).annotate("this is a comment").to_sql
    # SELECT "posts".* FROM "posts" WHERE "posts"."id" = 123 /* this is a comment */
    ```

    This can be useful in instrumentation or other analysis of issued queries.

    *Matt Yoho*

*   Support Optimizer Hints.

    In most databases, a way to control the optimizer is by using optimizer hints,
    which can be specified within individual statements.

    Example (for MySQL):

        Topic.optimizer_hints("MAX_EXECUTION_TIME(50000)", "NO_INDEX_MERGE(topics)")
        # SELECT /*+ MAX_EXECUTION_TIME(50000) NO_INDEX_MERGE(topics) */ `topics`.* FROM `topics`

    Example (for PostgreSQL with pg_hint_plan):

        Topic.optimizer_hints("SeqScan(topics)", "Parallel(topics 8)")
        # SELECT /*+ SeqScan(topics) Parallel(topics 8) */ "topics".* FROM "topics"

    See also:

    * https://dev.mysql.com/doc/refman/8.0/en/optimizer-hints.html
    * https://pghintplan.osdn.jp/pg_hint_plan.html
    * https://docs.oracle.com/en/database/oracle/oracle-database/12.2/tgsql/influencing-the-optimizer.html
    * https://docs.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-2017
    * https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.admin.perf.doc/doc/c0070117.html

    *Ryuta Kamizono*

*   Fix query attribute method on user-defined attribute to be aware of typecasted value.

    For example, the following code no longer return false as casted non-empty string:

    ```
    class Post < ActiveRecord::Base
      attribute :user_defined_text, :text
    end

    Post.new(user_defined_text: "false").user_defined_text? # => true
    ```

    *Yuji Kamijima*

*   Quote empty ranges like other empty enumerables.

    *Patrick Rebsch*

*   Add `insert_all`/`insert_all!`/`upsert_all` methods to `ActiveRecord::Persistence`,
    allowing bulk inserts akin to the bulk updates provided by `update_all` and
    bulk deletes by `delete_all`.

    Supports skipping or upserting duplicates through the `ON CONFLICT` syntax
    for PostgreSQL (9.5+) and SQLite (3.24+) and `ON DUPLICATE KEY UPDATE` syntax
    for MySQL.

    *Bob Lail*

*   Add `rails db:seed:replant` that truncates tables of each database
    for current environment and loads the seeds.

    *bogdanvlviv*, *DHH*

*   Add `ActiveRecord::Base.connection.truncate` for SQLite3 adapter.

    *bogdanvlviv*

*   Deprecate mismatched collation comparison for uniqueness validator.

    Uniqueness validator will no longer enforce case sensitive comparison in Rails 6.1.
    To continue case sensitive comparison on the case insensitive column,
    pass `case_sensitive: true` option explicitly to the uniqueness validator.

    *Ryuta Kamizono*

*   Add `reselect` method. This is a short-hand for `unscope(:select).select(fields)`.

    Fixes #27340.

    *Willian Gustavo Veiga*

*   Add negative scopes for all enum values.

    Example:

        class Post < ActiveRecord::Base
          enum status: %i[ drafted active trashed ]
        end

        Post.not_drafted # => where.not(status: :drafted)
        Post.not_active  # => where.not(status: :active)
        Post.not_trashed # => where.not(status: :trashed)

    *DHH*

*   Fix different `count` calculation when using `size` with manual `select` with DISTINCT.

    Fixes #35214.

    *Juani Villarejo*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   Fix prepared statements caching to be enabled even when query caching is enabled.

    *Ryuta Kamizono*

*   Ensure `update_all` series cares about optimistic locking.

    *Ryuta Kamizono*

*   Don't allow `where` with non numeric string matches to 0 values.

    *Ryuta Kamizono*

*   Introduce `ActiveRecord::Relation#destroy_by` and `ActiveRecord::Relation#delete_by`.

    `destroy_by` allows relation to find all the records matching the condition and perform
    `destroy_all` on the matched records.

    Example:

        Person.destroy_by(name: 'David')
        Person.destroy_by(name: 'David', rating: 4)

        david = Person.find_by(name: 'David')
        david.posts.destroy_by(id: [1, 2, 3])

    `delete_by` allows relation to find all the records matching the condition and perform
    `delete_all` on the matched records.

    Example:

        Person.delete_by(name: 'David')
        Person.delete_by(name: 'David', rating: 4)

        david = Person.find_by(name: 'David')
        david.posts.delete_by(id: [1, 2, 3])

    *Abhay Nikam*

*   Don't allow `where` with invalid value matches to nil values.

    Fixes #33624.

    *Ryuta Kamizono*

*   SQLite3: Implement `add_foreign_key` and `remove_foreign_key`.

    *Ryuta Kamizono*

*   Deprecate using class level querying methods if the receiver scope
    regarded as leaked. Use `klass.unscoped` to avoid the leaking scope.

    *Ryuta Kamizono*

*   Allow applications to automatically switch connections.

    Adds a middleware and configuration options that can be used in your
    application to automatically switch between the writing and reading
    database connections.

    `GET` and `HEAD` requests will read from the replica unless there was
    a write in the last 2 seconds, otherwise they will read from the primary.
    Non-get requests will always write to the primary. The middleware accepts
    an argument for a Resolver class and an Operations class where you are able
    to change how the auto-switcher works to be most beneficial for your
    application.

    To use the middleware in your application you can use the following
    configuration options:

    ```
    config.active_record.database_selector = { delay: 2.seconds }
    config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
    config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
    ```

    To change the database selection strategy, pass a custom class to the
    configuration options:

    ```
    config.active_record.database_selector = { delay: 10.seconds }
    config.active_record.database_resolver = MyResolver
    config.active_record.database_resolver_context = MyResolver::MyCookies
    ```

    *Eileen M. Uchitelle*

*   MySQL: Support `:size` option to change text and blob size.

    *Ryuta Kamizono*

*   Make `t.timestamps` with precision by default.

    *Ryuta Kamizono*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   Remove deprecated `#set_state` from the transaction object.

    *Rafael Mendonça França*

*   Remove deprecated `#supports_statement_cache?` from the database adapters.

    *Rafael Mendonça França*

*   Remove deprecated `#insert_fixtures` from the database adapters.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SQLite3Adapter#valid_alter_table_type?`.

    *Rafael Mendonça França*

*   Do not allow passing the column name to `sum` when a block is passed.

    *Rafael Mendonça França*

*   Do not allow passing the column name to `count` when a block is passed.

    *Rafael Mendonça França*

*   Remove delegation of missing methods in a relation to arel.

    *Rafael Mendonça França*

*   Remove delegation of missing methods in a relation to private methods of the class.

    *Rafael Mendonça França*

*   Deprecate `config.active_record.sqlite3.represent_boolean_as_integer`.

    *Rafael Mendonça França*

*   Change `SQLite3Adapter` to always represent boolean values as integers.

    *Rafael Mendonça França*

*   Remove ability to specify a timestamp name for `#cache_key`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Migrator.migrations_path=`.

    *Rafael Mendonça França*

*   Remove deprecated `expand_hash_conditions_for_aggregates`.

    *Rafael Mendonça França*

*   Set polymorphic type column to NULL on `dependent: :nullify` strategy.

    On polymorphic associations both the foreign key and the foreign type columns will be set to NULL.

    *Laerti Papa*

*   Allow permitted instance of `ActionController::Parameters` as argument of `ActiveRecord::Relation#exists?`.

    *Gannon McGibbon*

*   Add support for endless ranges introduces in Ruby 2.6.

    *Greg Navis*

*   Deprecate passing `migrations_paths` to `connection.assume_migrated_upto_version`.

    *Ryuta Kamizono*

*   MySQL: `ROW_FORMAT=DYNAMIC` create table option by default.

    Since MySQL 5.7.9, the `innodb_default_row_format` option defines the default row
    format for InnoDB tables. The default setting is `DYNAMIC`.
    The row format is required for indexing on `varchar(255)` with `utf8mb4` columns.

    *Ryuta Kamizono*

*   Fix join table column quoting with SQLite.

    *Gannon McGibbon*

*   Allow disabling scopes generated by `ActiveRecord.enum`.

    *Alfred Dominic*

*   Ensure that `delete_all` on collection proxy returns affected count.

    *Ryuta Kamizono*

*   Reset scope after delete on collection association to clear stale offsets of removed records.

    *Gannon McGibbon*

*   Add the ability to prevent writes to a database for the duration of a block.

    Allows the application to prevent writes to a database. This can be useful when
    you're building out multiple databases and want to make sure you're not sending
    writes when you want a read.

    If `while_preventing_writes` is called and the query is considered a write
    query the database will raise an exception regardless of whether the database
    user is able to write.

    This is not meant to be a catch-all for write queries but rather a way to enforce
    read-only queries without opening a second connection. One purpose of this is to
    catch accidental writes, not all writes.

    *Eileen M. Uchitelle*

*   Allow aliased attributes to be used in `#update_columns` and `#update`.

    *Gannon McGibbon*

*   Allow spaces in postgres table names.

    Fixes issue where "user post" is misinterpreted as "\"user\".\"post\"" when quoting table names with the postgres adapter.

    *Gannon McGibbon*

*   Cached `columns_hash` fields should be excluded from `ResultSet#column_types`.

    PR #34528 addresses the inconsistent behaviour when attribute is defined for an ignored column. The following test
    was passing for SQLite and MySQL, but failed for PostgreSQL:

    ```ruby
    class DeveloperName < ActiveRecord::Type::String
      def deserialize(value)
        "Developer: #{value}"
      end
    end

    class AttributedDeveloper < ActiveRecord::Base
      self.table_name = "developers"

      attribute :name, DeveloperName.new

      self.ignored_columns += ["name"]
    end

    developer = AttributedDeveloper.create
    developer.update_column :name, "name"

    loaded_developer = AttributedDeveloper.where(id: developer.id).select("*").first
    puts loaded_developer.name # should be "Developer: name" but it's just "name"
    ```

    *Dmitry Tsepelev*

*   Make the implicit order column configurable.

    When calling ordered finder methods such as `first` or `last` without an
    explicit order clause, ActiveRecord sorts records by primary key. This can
    result in unpredictable and surprising behaviour when the primary key is
    not an auto-incrementing integer, for example when it's a UUID. This change
    makes it possible to override the column used for implicit ordering such
    that `first` and `last` will return more predictable results.

    Example:

        class Project < ActiveRecord::Base
          self.implicit_order_column = "created_at"
        end

    *Tekin Suleyman*

*   Bump minimum PostgreSQL version to 9.3.

    *Yasuo Honda*

*   Values of enum are frozen, raising an error when attempting to modify them.

    *Emmanuel Byrd*

*   Move `ActiveRecord::StatementInvalid` SQL to error property and include binds as separate error property.

    `ActiveRecord::ConnectionAdapters::AbstractAdapter#translate_exception_class` now requires `binds` to be passed as the last argument.

    `ActiveRecord::ConnectionAdapters::AbstractAdapter#translate_exception` now requires `message`, `sql`, and `binds` to be passed as keyword arguments.

    Subclasses of `ActiveRecord::StatementInvalid` must now provide `sql:` and `binds:` arguments to `super`.

    Example:

    ```
    class MySubclassedError < ActiveRecord::StatementInvalid
      def initialize(message, sql:, binds:)
        super(message, sql: sql, binds: binds)
      end
    end
    ```

    *Gannon McGibbon*

*   Add an `:if_not_exists` option to `create_table`.

    Example:

        create_table :posts, if_not_exists: true do |t|
          t.string :title
        end

    That would execute:

        CREATE TABLE IF NOT EXISTS posts (
          ...
        )

    If the table already exists, `if_not_exists: false` (the default) raises an
    exception whereas `if_not_exists: true` does nothing.

    *fatkodima*, *Stefan Kanev*

*   Defining an Enum as a Hash with blank key, or as an Array with a blank value, now raises an `ArgumentError`.

    *Christophe Maximin*

*   Adds support for multiple databases to `rails db:schema:cache:dump` and `rails db:schema:cache:clear`.

    *Gannon McGibbon*

*   `update_columns` now correctly raises `ActiveModel::MissingAttributeError`
    if the attribute does not exist.

    *Sean Griffin*

*   Add support for hash and URL configs in database hash of `ActiveRecord::Base.connected_to`.

    ````
    User.connected_to(database: { writing: "postgres://foo" }) do
      User.create!(name: "Gannon")
    end

    config = { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" }
    User.connected_to(database: { reading: config }) do
      User.count
    end
    ````

    *Gannon McGibbon*

*   Support default expression for MySQL.

    MySQL 8.0.13 and higher supports default value to be a function or expression.

    https://dev.mysql.com/doc/refman/8.0/en/create-table.html

    *Ryuta Kamizono*

*   Support expression indexes for MySQL.

    MySQL 8.0.13 and higher supports functional key parts that index
    expression values rather than column or column prefix values.

    https://dev.mysql.com/doc/refman/8.0/en/create-index.html

    *Ryuta Kamizono*

*   Fix collection cache key with limit and custom select to avoid ambiguous timestamp column error.

    Fixes #33056.

    *Federico Martinez*

*   Add basic API for connection switching to support multiple databases.

    1) Adds a `connects_to` method for models to connect to multiple databases. Example:

    ```
    class AnimalsModel < ApplicationRecord
      self.abstract_class = true

      connects_to database: { writing: :animals_primary, reading: :animals_replica }
    end

    class Dog < AnimalsModel
      # connected to both the animals_primary db for writing and the animals_replica for reading
    end
    ```

    2) Adds a `connected_to` block method for switching connection roles or connecting to
    a database that the model didn't connect to. Connecting to the database in this block is
    useful when you have another defined connection, for example `slow_replica` that you don't
    want to connect to by default but need in the console, or a specific code block.

    ```
    ActiveRecord::Base.connected_to(role: :reading) do
      Dog.first # finds dog from replica connected to AnimalsBase
      Book.first # doesn't have a reading connection, will raise an error
    end
    ```

    ```
    ActiveRecord::Base.connected_to(database: :slow_replica) do
      SlowReplicaModel.first # if the db config has a slow_replica configuration this will be used to do the lookup, otherwise this will throw an exception
    end
    ```

    *Eileen M. Uchitelle*

*   Enum raises on invalid definition values

    When defining a Hash enum it can be easy to use `[]` instead of `{}`. This
    commit checks that only valid definition values are provided, those can
    be a Hash, an array of Symbols or an array of Strings. Otherwise it
    raises an `ArgumentError`.

    Fixes #33961

    *Alberto Almagro*

*   Reloading associations now clears the Query Cache like `Persistence#reload` does.

    ```
    class Post < ActiveRecord::Base
      has_one :category
      belongs_to :author
      has_many :comments
    end

    # Each of the following will now clear the query cache.
    post.reload_category
    post.reload_author
    post.comments.reload
    ```

    *Christophe Maximin*

*   Added `index` option for `change_table` migration helpers.
    With this change you can create indexes while adding new
    columns into the existing tables.

    Example:

        change_table(:languages) do |t|
          t.string :country_code, index: true
        end

    *Mehmet Emin İNAÇ*

*   Fix `transaction` reverting for migrations.

    Before: Commands inside a `transaction` in a reverted migration ran uninverted.
    Now: This change fixes that by reverting commands inside `transaction` block.

    *fatkodima*, *David Verhasselt*

*   Raise an error instead of scanning the filesystem root when `fixture_path` is blank.

    *Gannon McGibbon*, *Max Albrecht*

*   Allow `ActiveRecord::Base.configurations=` to be set with a symbolized hash.

    *Gannon McGibbon*

*   Don't update counter cache unless the record is actually saved.

    Fixes #31493, #33113, #33117.

    *Ryuta Kamizono*

*   Deprecate `ActiveRecord::Result#to_hash` in favor of `ActiveRecord::Result#to_a`.

    *Gannon McGibbon*, *Kevin Cheng*

*   SQLite3 adapter supports expression indexes.

    ```
    create_table :users do |t|
      t.string :email
    end

    add_index :users, 'lower(email)', name: 'index_users_on_email', unique: true
    ```

    *Gray Kemmey*

*   Allow subclasses to redefine autosave callbacks for associated records.

    Fixes #33305.

    *Andrey Subbota*

*   Bump minimum MySQL version to 5.5.8.

    *Yasuo Honda*

*   Use MySQL utf8mb4 character set by default.

    `utf8mb4` character set with 4-Byte encoding supports supplementary characters including emoji.
    The previous default 3-Byte encoding character set `utf8` is not enough to support them.

    *Yasuo Honda*

*   Fix duplicated record creation when using nested attributes with `create_with`.

    *Darwin Wu*

*   Configuration item `config.filter_parameters` could also filter out
    sensitive values of database columns when calling `#inspect`.
    We also added `ActiveRecord::Base::filter_attributes`/`=` in order to
    specify sensitive attributes to specific model.

    ```
    Rails.application.config.filter_parameters += [:credit_card_number, /phone/]
    Account.last.inspect # => #<Account id: 123, name: "DHH", credit_card_number: [FILTERED], telephone_number: [FILTERED] ...>
    SecureAccount.filter_attributes += [:name]
    SecureAccount.last.inspect # => #<SecureAccount id: 42, name: [FILTERED], credit_card_number: [FILTERED] ...>
    ```

    *Zhang Kang*, *Yoshiyuki Kinjo*

*   Deprecate `column_name_length`, `table_name_length`, `columns_per_table`,
    `indexes_per_table`, `columns_per_multicolumn_index`, `sql_query_length`,
    and `joins_per_query` methods in `DatabaseLimits`.

    *Ryuta Kamizono*

*   `ActiveRecord::Base.configurations` now returns an object.

    `ActiveRecord::Base.configurations` used to return a hash, but this
    is an inflexible data model. In order to improve multiple-database
    handling in Rails, we've changed this to return an object. Some methods
    are provided to make the object behave hash-like in order to ease the
    transition process. Since most applications don't manipulate the hash
    we've decided to add backwards-compatible functionality that will throw
    a deprecation warning if used, however calling `ActiveRecord::Base.configurations`
    will use the new version internally and externally.

    For example, the following `database.yml`:

    ```
    development:
      adapter: sqlite3
      database: db/development.sqlite3
    ```

    Used to become a hash:

    ```
    { "development" => { "adapter" => "sqlite3", "database" => "db/development.sqlite3" } }
    ```

    Is now converted into the following object:

    ```
    #<ActiveRecord::DatabaseConfigurations:0x00007fd1acbdf800 @configurations=[
      #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd1acbded10 @env_name="development",
        @spec_name="primary", @config={"adapter"=>"sqlite3", "database"=>"db/development.sqlite3"}>
      ]
    ```

    Iterating over the database configurations has also changed. Instead of
    calling hash methods on the `configurations` hash directly, a new method `configs_for` has
    been provided that allows you to select the correct configuration. `env_name` and
    `spec_name` arguments are optional. For example, these return an array of
    database config objects for the requested environment and a single database config object
    will be returned for the requested environment and specification name respectively.

    ```
    ActiveRecord::Base.configurations.configs_for(env_name: "development")
    ActiveRecord::Base.configurations.configs_for(env_name: "development", spec_name: "primary")
    ```

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Add database configuration to disable advisory locks.

    ```
    production:
      adapter: postgresql
      advisory_locks: false
    ```

    *Guo Xiang*

*   SQLite3 adapter `alter_table` method restores foreign keys.

    *Yasuo Honda*

*   Allow `:to_table` option to `invert_remove_foreign_key`.

    Example:

       remove_foreign_key :accounts, to_table: :owners

    *Nikolay Epifanov*, *Rich Chen*

*   Add environment & load_config dependency to `bin/rake db:seed` to enable
    seed load in environments without Rails and custom DB configuration

    *Tobias Bielohlawek*

*   Fix default value for mysql time types with specified precision.

    *Nikolay Kondratyev*

*   Fix `touch` option to behave consistently with `Persistence#touch` method.

    *Ryuta Kamizono*

*   Migrations raise when duplicate column definition.

    Fixes #33024.

    *Federico Martinez*

*   Bump minimum SQLite version to 3.8

    *Yasuo Honda*

*   Fix parent record should not get saved with duplicate children records.

    Fixes #32940.

    *Santosh Wadghule*

*   Fix logic on disabling commit callbacks so they are not called unexpectedly when errors occur.

    *Brian Durand*

*   Ensure `Associations::CollectionAssociation#size` and `Associations::CollectionAssociation#empty?`
    use loaded association ids if present.

    *Graham Turner*

*   Add support to preload associations of polymorphic associations when not all the records have the requested associations.

    *Dana Sherson*

*   Add `touch_all` method to `ActiveRecord::Relation`.

    Example:

        Person.where(name: "David").touch_all(time: Time.new(2020, 5, 16, 0, 0, 0))

    *fatkodima*, *duggiefresh*

*   Add `ActiveRecord::Base.base_class?` predicate.

    *Bogdan Gusiev*

*   Add custom prefix/suffix options to `ActiveRecord::Store.store_accessor`.

    *Tan Huynh*, *Yukio Mizuta*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*

*   Deprecate `update_attributes`/`!` in favor of `update`/`!`.

    *Eddie Lebow*

*   Add `ActiveRecord::Base.create_or_find_by`/`!` to deal with the SELECT/INSERT race condition in
    `ActiveRecord::Base.find_or_create_by`/`!` by leaning on unique constraints in the database.

    *DHH*

*   Add `Relation#pick` as short-hand for single-value plucks.

    *DHH*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activerecord/CHANGELOG.md) for previous changes.
