## Rails 5.0.7.2 (March 11, 2019) ##

*   No changes.


## Rails 5.0.7.1 (November 27, 2018) ##

*   No changes.


## Rails 5.0.7 (March 29, 2018) ##

*   Apply time column precision on assignment.

    PR #20317 changed the behavior of datetime columns so that when they
    have a specified precision then on assignment the value is rounded to
    that precision. This behavior is now applied to time columns as well.

    Fixes #30301.

    *Andrew White*

*   Normalize time column values for SQLite database.

    For legacy reasons, time columns in SQLite are stored as full datetimes
    because until #24542 the quoting for time columns didn't remove the date
    component. To ensure that values are consistent we now normalize the
    date component to 2001-01-01 on reading and writing.

    *Andrew White*

*   Ensure that the date component is removed when quoting times.

    PR #24542 altered the quoting for time columns so that the date component
    was removed however it only removed it when it was 2001-01-01. Now the
    date component is removed irrespective of what the date is.

    *Andrew White*

*   Query cache was unavailable when entering the `ActiveRecord::Base.cache` block
    without being connected.

    *Tsukasa Oishi*

*   Fix `bin/rails db:setup` and `bin/rails db:test:prepare` create  wrong
    ar_internal_metadata's data for a test database.

    Before:
    ```
    $ RAILS_ENV=test rails dbconsole
    > SELECT * FROM ar_internal_metadata;
    key|value|created_at|updated_at
    environment|development|2017-09-11 23:14:10.815679|2017-09-11 23:14:10.815679
    ```

    After:
    ```
    $ RAILS_ENV=test rails dbconsole
    > SELECT * FROM ar_internal_metadata;
    key|value|created_at|updated_at
    environment|test|2017-09-11 23:14:10.815679|2017-09-11 23:14:10.815679
    ```

    Fixes #26731.

    *bogdanvlviv*

*   Fix longer sequence name detection for serial columns.

    Fixes #28332.

    *Ryuta Kamizono*

*   Use `max_identifier_length` for `index_name_length` in PostgreSQL adapter.

    *Ryuta Kamizono*


## Rails 5.0.6 (September 07, 2017) ##

*   No changes.


## Rails 5.0.6.rc1 (August 24, 2017) ##

*   Ensure `sum` honors `distinct` on `has_many :through` associations

    Fixes #16791

    *Aaron Wortham


## Rails 5.0.5 (July 31, 2017) ##

*   No changes.


## Rails 5.0.5.rc2 (July 25, 2017) ##

*   No changes.


## Rails 5.0.5.rc1 (July 19, 2017) ##

*   `Relation#joins` is no longer affected by the target model's
    `current_scope`, with the exception of `unscoped`.

    Fixes #29338.

    *Sean Griffin*


## Rails 5.0.4 (June 19, 2017) ##

*   Restore previous behavior of collection proxies: their values can have
    methods stubbed, and they respect extension modules applied by a default
    scope.

    *Ryuta Kamizono*

*   Loading model schema from database is now thread-safe.

    Fixes #28589.

    *Vikrant Chaudhary*, *David Abdemoulaie*


## Rails 5.0.3 (May 12, 2017) ##

*   Check whether `Rails.application` defined before calling it

    In #27674 we changed the migration generator to generate migrations at the
    path defined in `Rails.application.config.paths` however the code checked
    for the presence of the `Rails` constant but not the `Rails.application`
    method which caused problems when using Active Record and generators outside
    of the context of a Rails application.

    Fixes #28325.

*   Fix `deserialize` with JSON array.

    Fixes #28285.

    *Ryuta Kamizono*

*   Fix `rake db:schema:load` with subdirectories.

    *Ryuta Kamizono*

*   Fix `rake db:migrate:status` with subdirectories.

    *Ryuta Kamizono*

*   Don't share options between reference id and type columns

    When using a polymorphic reference column in a migration, sharing options
    between the two columns doesn't make sense since they are different types.
    The `reference_id` column is usually an integer and the `reference_type`
    column a string so options like `unsigned: true` will result in an invalid
    table definition.

    *Ryuta Kamizono*

*   Fix regression of #1969 with SELECT aliases in HAVING clause.

    *Eugene Kenny*


## Rails 5.0.2 (March 01, 2017) ##

*   Fix `wait_timeout` to configurable for mysql2 adapter.

    Fixes #26556.

    *Ryuta Kamizono*

*   Make `table_name=` reset current statement cache,
    so queries are not run against the previous table name.

    *namusyaka*

*   Allow ActiveRecord::Base#as_json to be passed a frozen Hash.

    *Isaac Betesh*

*   Fix inspection behavior when the :id column is not primary key.

    *namusyaka*

*   Fix `association_primary_key_type` for reflections with symbol primary key

    Fixes #27864

    *Daniel Colson*

*   Place generated migrations into the path set by `config.paths["db/migrate"]`

    *Kevin Glowacz*

*   Compare deserialized values for `PostgreSQL::OID::Hstore` types when
    calling `ActiveRecord::Dirty#changed_in_place?`

    Fixes #27502.

    *Jon Moss*

*   Respect precision option for arrays of timestamps.

    Fixes #27514.

    *Sean Griffin*


## Rails 5.0.1 (December 21, 2016) ##

*   No changes.


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   Correct resolution of associated class in `has_many :through`
    associations' `*_ids` setters.

    Fixes #27297.

    *Matthew Draper*

*   Support index length and order options using both string and symbol
    column names.

    Fixes #27243.

    *Ryuta Kamizono*


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   Fix that unsigned with zerofill is treated as signed.

    Fixes #27125.

    *Ryuta Kamizono*

*   Fix the uniqueness validation scope with a polymorphic association.

    *Sergey Alekseev*

*   Raise ActiveRecord::RecordNotFound from collection `*_ids` setters
    for unknown IDs with a better error message.

    Changes the collection `*_ids` setters to cast provided IDs the data
    type of the primary key set in the association, not the model
    primary key.

    *Dominic Cleal*

*   Introduce `Model#reload_<association>` to bring back the behavior
    of `Article.category(true)` where `category` is a singular
    association.

    The force reloading of the association reader was deprecated
    in #20888. Unfortunately the suggested alternative of
    `article.reload.category` does not expose the same behavior.

    This patch adds a reader method with the prefix `reload_` for
    singular associations. This method has the same semantics as
    passing true to the association reader used to have.

    *Yves Senn*

*   Make sure eager loading `ActiveRecord::Associations` also loads
    constants defined in `ActiveRecord::Associations::Preloader`.

    *Yves Senn*

*   Allow `ActionController::Parameters`-like objects to be passed as
    values for Postgres HStore columns.

    Fixes #26904.

    *Jon Moss*

*   Configure query caching (per thread) on the connection pool.

    Moving the configuration to the pool means we don't allocate a connection
    until it's actually needed.

    Applications that manually interact with the connection pool and/or query
    cache may notice that the connection's cache is now cleared and disabled
    when it gets returned to the pool, even if the request is not yet completed.

    *Samuel Cochran*, *Matthew Draper*

*   Fixed support for case insensitive comparisons of `text` columns in
    PostgreSQL.

    *Edho Arief*

*   Return `true` from `update_attribute` when the value of the attribute
    to be updated is unchanged.

    Fixes #26593.

    *Prathamesh Sonpatki*

*   Serialize JSON attribute value `nil` as SQL `NULL`, not JSON `null`

    *Trung Duc Tran*

*   Always store errors details information with symbols.

    When the association is autosaved we were storing the details with
    string keys. This was creating inconsistency with other details that are
    added using the `Errors#add` method. It was also inconsistent with the
    `Errors#messages` storage.

    To fix this inconsistency we are always storing with symbols. This will
    cause a small breaking change because in those cases the details could
    be accessed as strings keys but now it can not.

    Fix #26499.

    *Rafael Mendonça França*, *Marcus Vieira*

*   Using a mysql2 connection after it fails to reconnect will now have an error message
    saying the connection is closed rather than an undefined method error message.

    *Dylan Thacker-Smith*

*   Remove unnecessarily association load when a `belongs_to` association has already been
    loaded then the foreign key is changed directly and the record saved.

    *James Coleman*

*   PostgreSQL array columns will now respect the encoding of strings contained
    in the array.

    Fixes #26326.

    *Sean Griffin*

*   Inverse association instances will now be set before `after_find` or
    `after_initialize` callbacks are run.

    Fixes #26320.

    *Sean Griffin*

*   Avoid loading records from database when they are already loaded using
    the `pluck` method on a collection.

    Fixes #25921.

    *Ryuta Kamizono*

*   Sqlite3 migrations to add a column to an existing table can now be
    successfully rolled back when the column was given and invalid column
    type.

    Fixes #26087

    *Travis O'Neill*

*   Hashes can once again be passed to setters of `composed_of`, if all of the
    mapping methods are methods implemented on `Hash`.

    Fixes #25978.

    *Sean Griffin*

*   Doing count on relations that contain LEFT OUTER JOIN Arel node no longer
    force a DISTINCT. This solves issues when using count after a left_joins.

    *Maxime Handfield Lapointe*

*   RecordNotFound raised by association.find exposes `id`, `primary_key` and
    `model` methods to be consistent with RecordNotFound raised by Record.find.

    *Michel Pigassou*

*   Fix the SELECT statement in `#table_comment` for MySQL.

    *Takeshi Akima*

*   Virtual attributes will no longer raise when read on models loaded from the
    database

    *Sean Griffin*

*   Fixes multi-parameter attributes conversion with invalid params.

    *Hiroyuki Ishii*

*   Add newline between each migration in `structure.sql`.

    Keeps schema migration inserts as a single commit, but allows for easier
    git diff-ing. Fixes #25504.

    *Grey Baker*, *Norberto Lopes*

*   Using `group` with an attribute that has a custom type will properly cast
    the hash keys after calling a calculation method like `count`.

    Fixes #25595.

    *Sean Griffin*

*   Ensure concurrent invocations of the connection reaper cannot allocate the
    same connection to two threads.

    Fixes #25585.

    *Matthew Draper*

*   Fixed dumping of foreign key's referential actions when MySQL connection
    uses `sql_mode = ANSI_QUOTES`.

    Fixes #25300.

    *Ryuta Kamizono*


## Rails 5.0.0 (June 30, 2016) ##

*   Inspecting an object with an associated array of over 10 elements no longer
    truncates the array, preventing `inspect` from looping infinitely in some
    cases.

    *Kevin McPhillips*

*   Ensure hashes can be assigned to attributes created using `composed_of`.

    Fixes #25210.

    *Sean Griffin*

*   Fix logging edge case where if an attribute was of the binary type and
    was provided as a Hash.

    *Jon Moss*

*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

    *Johannes Opper*

*   PostgreSQL: Support Expression Indexes and Operator Classes.

    Example:

        create_table :users do |t|
          t.string :name
          t.index 'lower(name) varchar_pattern_ops'
        end

    Fixes #19090, #21765, #21819, #24359.

    *Ryuta Kamizono*

*   MySQL: Prepared statements support.

    To enable, set `prepared_statements: true` in config/database.yml.
    Requires mysql2 0.4.4+.

    *Ryuta Kamizono*

*   Schema dumper: Indexes are now included in the `create_table` block
    instead of listed afterward as separate `add_index` lines.

    This tidies up schema.rb and makes it easy to read as a list of tables.

    Bonus: Allows databases that support it (MySQL) to perform as single
    `CREATE TABLE` query, no additional query per index.

    *Ryuta Kamizono*

*   SQLite: Fix uniqueness validation when values exceed the column limit.

    SQLite doesn't impose length restrictions on strings, BLOBs, or numeric
    values. It treats them as helpful metadata. When we truncate strings
    before checking uniqueness, we'd miss values that exceed the column limit.

    Other databases enforce length limits. A large value will pass uniqueness
    validation since the column limit guarantees no value that long exists.
    When we insert the row, it'll raise `ActiveRecord::ValueTooLong` as we
    expect.

    This fixes edge-case incorrect validation failures for values that exceed
    the column limit but are identical to an existing value *when truncated*.
    Now these will pass validation and raise an exception.

    *Ryuta Kamizono*

*   Raise `ActiveRecord::ValueTooLong` when column limits are exceeded.
    Supported by MySQL and PostgreSQL adapters.

    *Ryuta Kamizono*

*   Migrations: `#foreign_key` respects `table_name_prefix` and `_suffix`.

    *Ryuta Kamizono*

*   SQLite: Force NOT NULL primary keys.

    From SQLite docs: https://www.sqlite.org/lang_createtable.html
        According to the SQL standard, PRIMARY KEY should always imply NOT
        NULL. Unfortunately, due to a bug in some early versions, this is not
        the case in SQLite. Unless the column is an INTEGER PRIMARY KEY or the
        table is a WITHOUT ROWID table or the column is declared NOT NULL,
        SQLite allows NULL values in a PRIMARY KEY column. SQLite could be
        fixed to conform to the standard, but doing so might break legacy
        applications. Hence, it has been decided to merely document the fact
        that SQLite allowing NULLs in most PRIMARY KEY columns.

    Now we override column options to explicitly set NOT NULL rather than rely
    on implicit NOT NULL like MySQL and PostgreSQL adapters.

    *Ryuta Kamizono*

*   Added notice when a database is successfully created or dropped.

    Example:

        $ bin/rails db:create
        Created database 'blog_development'
        Created database 'blog_test'

        $ bin/rails db:drop
        Dropped database 'blog_development'
        Dropped database 'blog_test'

    Changed older notices
    `blog_development already exists` to `Database 'blog_development' already exists`.
    and
    `Couldn't drop blog_development` to `Couldn't drop database 'blog_development'`.

    *bogdanvlviv*

*   Database comments. Annotate database objects (tables, columns, indexes)
    with comments stored in database metadata. PostgreSQL & MySQL support.

        create_table :pages, force: :cascade, comment: 'CMS content pages' do |t|
          t.string :path,   comment: 'Path fragment of page URL used for routing'
          t.string :locale, comment: 'RFC 3066 locale code of website language section'
          t.index [:path, :locale], comment: 'Look up pages by URI'
        end

    *Andrey Novikov*

*   Add `quoted_time` for truncating the date part of a TIME column value.
    This fixes queries on TIME column on MariaDB, as it doesn't ignore the
    date part of the string when it coerces to time.

    *Ryuta Kamizono*

*   Properly accept all valid JSON primitives in the JSON data type.

    Fixes #24234

    *Sean Griffin*

*   MariaDB 5.3+ supports microsecond datetime precision.

    *Jeremy Daer*

*   Delegate `none?` and `one?`. Now they can be invoked as model class methods.

    Example:

        # When no record is found on the table
        Topic.none?  # => true

        # When only one record is found on the table
        Topic.one?   # => true

    *Kenta Shirai*

*   The form builder now properly displays values when passing a proc form
    default to the attributes API.

    Fixes #24249.

    *Sean Griffin*

*   The schema cache is now cleared after the `db:migrate` task is run.

    Closes #24273.

    *Chris Arcand*

*   MySQL: strict mode respects other SQL modes rather than overwriting them.
    Setting `strict: true` adds `STRICT_ALL_TABLES` to `sql_mode`. Setting
    `strict: false` removes `STRICT_TRANS_TABLES`, `STRICT_ALL_TABLES`, and
    `TRADITIONAL` from `sql_mode`.

    *Ryuta Kamizono*

*   Execute default_scope defined by abstract class in the context of subclass.

    Fixes #23413.
    Fixes #10658.

    *Mehmet Emin İNAÇ*

*   Fix an issue when preloading associations with extensions.
    Previously every association with extension methods was transformed into an
    instance dependent scope. This is no longer the case.

    Fixes #23934.

    *Yves Senn*

*   Deprecate `{insert|update|delete}_sql` in `DatabaseStatements`.
    Use the `{insert|update|delete}` public methods instead.

    *Ryuta Kamizono*

*   Added a configuration option to have active record raise an ArgumentError
    if the order or limit is ignored in a batch query, rather than logging a
    warning message.

    *Scott Ringwelski*

*   Honour the order of the joining model in a `has_many :through` association when eager loading.

    Example:

    The below will now follow the order of `by_lines` when eager loading `authors`.

        class Article < ActiveRecord::Base
          has_many :by_lines, -> { order(:position) }
          has_many :authors, through: :by_lines
        end

    Fixes #17864.

    *Yasyf Mohamedali*, *Joel Turkel*

*   Ensure that the Suppressor runs before validations.

    This moves the suppressor up to be run before validations rather than after
    validations. There's no reason to validate a record you aren't planning on saving.

    *Eileen M. Uchitelle*

*   Save many-to-many objects based on association primary key.

    Fixes #20995.

    *himesh-r*

*   Ensure that mutations of the array returned from `ActiveRecord::Relation#to_a`
    do not affect the original relation, by returning a duplicate array each time.

    This brings the behavior in line with `CollectionProxy#to_a`, which was
    already more careful.

    *Matthew Draper*

*   Fixed `where` for polymorphic associations when passed an array containing different types.

    Fixes #17011.

    Example:

        PriceEstimate.where(estimate_of: [Treasure.find(1), Car.find(2)])
        # => SELECT "price_estimates".* FROM "price_estimates"
             WHERE (("price_estimates"."estimate_of_type" = 'Treasure' AND "price_estimates"."estimate_of_id" = 1)
             OR ("price_estimates"."estimate_of_type" = 'Car' AND "price_estimates"."estimate_of_id" = 2))

    *Philippe Huibonhoa*

*   Fix a bug where using `t.foreign_key` twice with the same `to_table` within
    the same table definition would only create one foreign key.

    *George Millo*

*   Fix a regression on has many association, where calling a child from parent in child's callback
    results in same child records getting added repeatedly to target.

    Fixes #13387.

    *Bogdan Gusiev*, *Jon Hinson*

*   Rework `ActiveRecord::Relation#last`.

    1. Never perform additional SQL on loaded relation
    2. Use SQL reverse order instead of loading relation if relation doesn't have limit
    3. Deprecated relation loading when SQL order can not be automatically reversed

        Topic.order("title").load.last(3)
          # before: SELECT ...
          # after: No SQL

        Topic.order("title").last
          # before: SELECT * FROM `topics`
          # after:  SELECT * FROM `topics` ORDER BY `topics`.`title` DESC LIMIT 1

        Topic.order("coalesce(author, title)").last
          # before: SELECT * FROM `topics`
          # after:  Deprecation Warning for irreversible order

    *Bogdan Gusiev*

*   Allow `joins` to be unscoped.

    Fixes #13775.

    *Takashi Kokubun*

*   Add `#second_to_last` and `#third_to_last` finder methods.

    *Brian Christian*

*   Added `numeric` helper into migrations.

    Example:

        create_table(:numeric_types) do |t|
          t.numeric :numeric_type, precision: 10, scale: 2
        end

    *Mehmet Emin İNAÇ*

*   Bumped the minimum supported version of PostgreSQL to >= 9.1.
    Both PG 9.0 and 8.4 are past their end of life date:
    http://www.postgresql.org/support/versioning/

    *Remo Mueller*

*   `ActiveRecord::Relation#reverse_order` throws `ActiveRecord::IrreversibleOrderError`
    when the order can not be reversed using current trivial algorithm.
    Also raises the same error when `#reverse_order` is called on
    relation without any order and table has no primary key:

        Topic.order("concat(author_name, title)").reverse_order
          # Before: SELECT `topics`.* FROM `topics` ORDER BY concat(author_name DESC, title) DESC
          # After: raises ActiveRecord::IrreversibleOrderError
        Edge.all.reverse_order
          # Before: SELECT `edges`.* FROM `edges` ORDER BY `edges`.`` DESC
          # After: raises ActiveRecord::IrreversibleOrderError

    *Bogdan Gusiev*

*   Improve schema_migrations insertion performance by inserting all versions
    in one INSERT SQL.

    *Akira Matsuda*, *Naoto Koshikawa*

*   Using `references` or `belongs_to` in migrations will always add index
    for the referenced column by default, without adding `index: true` option
    to generated migration file. Users can opt out of this by passing
    `index: false`.

    Fixes #18146.

    *Matthew Draper*, *Prathamesh Sonpatki*

*   Run `type` attributes through attributes API type-casting before
    instantiating the corresponding subclass. This makes it possible to define
    custom STI mappings.

    Fixes #21986.

    *Yves Senn*

*   Don't try to quote functions or expressions passed to `:default` option if
    they are passed as procs.

    This will generate proper query with the passed function or expression for
    the default option, instead of trying to quote it in incorrect fashion.

    Example:

        create_table :posts do |t|
          t.datetime :published_at, default: -> { 'NOW()' }
        end

    *Ryuta Kamizono*

*   Fix regression when loading fixture files with symbol keys.

    Fixes #22584.

    *Yves Senn*

*   Use `version` column as primary key for schema_migrations table because
    `schema_migrations` versions are guaranteed to be unique.

    This makes it possible to use `update_attributes` on models that do
    not have a primary key.

    *Richard Schneeman*

*   Add short-hand methods for text and blob types in MySQL.

    In Pg and Sqlite3, `:text` and `:binary` have variable unlimited length.
    But in MySQL, these have limited length for each types (ref #21591, #21619).
    This change adds short-hand methods for each text and blob types.

    Example:

        create_table :foos do |t|
          t.tinyblob   :tiny_blob
          t.mediumblob :medium_blob
          t.longblob   :long_blob
          t.tinytext   :tiny_text
          t.mediumtext :medium_text
          t.longtext   :long_text
        end

    *Ryuta Kamizono*

*   Take into account UTC offset when assigning string representation of
    timestamp with offset specified to attribute of time type.

    *Andrey Novikov*

*   When calling `first` with a `limit` argument, return directly from the
    `loaded?` records if available.

    *Ben Woosley*

*   Deprecate sending the `offset` argument to `find_nth`. Please use the
    `offset` method on relation instead.

    *Ben Woosley*

*   Limit record touching to once per transaction.

    If you have a parent/grand-parent relation like:

        Comment belongs_to :message, touch: true
        Message belongs_to :project, touch: true
        Project belongs_to :account, touch: true

    When the lowest entry(`Comment`) is saved, now, it won't repeat the touch
    call multiple times for the parent records.

    Related #18606.

    *arthurnn*

*   Order the result of `find(ids)` to match the passed array, if the relation
    has no explicit order defined.

    Fixes #20338.

    *Miguel Grazziotin*, *Matthew Draper*

*   Omit default limit values in dumped schema. It's tidier, and if the defaults
    change in the future, we can address that via Migration API Versioning.

    *Jean Boussier*

*   Support passing the schema name as a prefix to table name in
    `ConnectionAdapters::SchemaStatements#indexes`. Previously the prefix would
    be considered a full part of the index name, and only the schema in the
    current search path would be considered.

    *Grey Baker*

*   Ignore index name in `index_exists?` and `remove_index` when not passed a
    name to check for.

    *Grey Baker*

*   Extract support for the legacy `mysql` database adapter from core. It will
    live on in a separate gem for now, but most users should just use `mysql2`.

    *Abdelkader Boudih*

*   ApplicationRecord is a new superclass for all app models, analogous to app
    controllers subclassing ApplicationController instead of
    ActionController::Base. This gives apps a single spot to configure app-wide
    model behavior.

    Newly generated applications have `app/models/application_record.rb`
    present by default.

    *Genadi Samokovarov*

*   Version the API presented to migration classes, so we can change parameter
    defaults without breaking existing migrations, or forcing them to be
    rewritten through a deprecation cycle.

    New migrations specify the Rails version they were written for:

        class AddStatusToOrders < ActiveRecord::Migration[5.0]
          def change
            # ...
          end
        end

    *Matthew Draper*, *Ravil Bayramgalin*

*   Use bind params for `limit` and `offset`. This will generate significantly
    fewer prepared statements for common tasks like pagination. To support this
    change, passing a string containing a comma to `limit` has been deprecated,
    and passing an Arel node to `limit` is no longer supported.

    Fixes #22250.

    *Sean Griffin*

*   Introduce after_{create,update,delete}_commit callbacks.

    Before:

        after_commit :add_to_index_later, on: :create
        after_commit :update_in_index_later, on: :update
        after_commit :remove_from_index_later, on: :destroy

    After:

        after_create_commit  :add_to_index_later
        after_update_commit  :update_in_index_later
        after_destroy_commit :remove_from_index_later

    Fixes #22515.

    *Genadi Samokovarov*

*   Respect the column default values for `inheritance_column` when
    instantiating records through the base class.

    Fixes #17121.

    Example:

        # The schema of BaseModel has `t.string :type, default: 'SubType'`
        subtype = BaseModel.new
        assert_equals SubType, subtype.class

    *Kuldeep Aggarwal*

*   Fix `rake db:structure:dump` on Postgres when multiple schemas are used.

    Fixes #22346.

    *Nick Muerdter*, *ckoenig*

*   Add schema dumping support for PostgreSQL geometric data types.

    *Ryuta Kamizono*

*   Except keys of `build_record`'s argument from `create_scope` in `initialize_attributes`.

    Fixes #21893.

    *Yuichiro Kaneko*

*   Deprecate `connection.tables` on the SQLite3 and MySQL adapters.
    Also deprecate passing arguments to `#tables`.
    And deprecate `table_exists?`.

    The `#tables` method of some adapters (mysql, mysql2, sqlite3) would return
    both tables and views while others (postgresql) just return tables. To make
    their behavior consistent, `#tables` will return only tables in the future.

    The `#table_exists?` method would check both tables and views. To make
    their behavior consistent with `#tables`, `#table_exists?` will check only
    tables in the future.

    *Yuichiro Kaneko*

*   Improve support for non Active Record objects on `validates_associated`

    Skipping `marked_for_destruction?` when the associated object does not responds
    to it make easier to validate virtual associations built on top of Active Model
    objects and/or serialized objects that implement a `valid?` instance method.

    *Kassio Borges*, *Lucas Mazza*

*   Change connection management middleware to return a new response with
    a body proxy, rather than mutating the original.

    *Kevin Buchanan*

*   Make `db:migrate:status` to render `1_some.rb` format migrate files.

    These files are in `db/migrate`:

        * 1_valid_people_have_last_names.rb
        * 20150819202140_irreversible_migration.rb
        * 20150823202140_add_admin_flag_to_users.rb
        * 20150823202141_migration_tests.rb
        * 2_we_need_reminders.rb
        * 3_innocent_jointable.rb

    Before:

        $ bundle exec rake db:migrate:status
        ...

         Status   Migration ID    Migration Name
        --------------------------------------------------
           up     001             ********** NO FILE **********
           up     002             ********** NO FILE **********
           up     003             ********** NO FILE **********
           up     20150819202140  Irreversible migration
           up     20150823202140  Add admin flag to users
           up     20150823202141  Migration tests

    After:

        $ bundle exec rake db:migrate:status
        ...

         Status   Migration ID    Migration Name
        --------------------------------------------------
           up     001             Valid people have last names
           up     002             We need reminders
           up     003             Innocent jointable
           up     20150819202140  Irreversible migration
           up     20150823202140  Add admin flag to users
           up     20150823202141  Migration tests

    *Yuichiro Kaneko*

*   Define `ActiveRecord::Sanitization.sanitize_sql_for_order` and use it inside
    `preprocess_order_args`.

    *Yuichiro Kaneko*

*   Allow bigint with default nil for avoiding auto increment primary key.

    *Ryuta Kamizono*

*   Remove `DEFAULT_CHARSET` and `DEFAULT_COLLATION` in `MySQLDatabaseTasks`.

    We should omit the collation entirely rather than providing a default.
    Then the choice is the responsibility of the server and MySQL distribution.

    *Ryuta Kamizono*

*   Alias `ActiveRecord::Relation#left_joins` to
    `ActiveRecord::Relation#left_outer_joins`.

    *Takashi Kokubun*

*   Use advisory locking to raise a `ConcurrentMigrationError` instead of
    attempting to migrate when another migration is currently running.

    *Sam Davies*

*   Added `ActiveRecord::Relation#left_outer_joins`.

    Example:

        User.left_outer_joins(:posts)
        # => SELECT "users".* FROM "users" LEFT OUTER JOIN "posts" ON
             "posts"."user_id" = "users"."id"

    *Florian Thomas*

*   Support passing an array to `order` for SQL parameter sanitization.

    *Aaron Suggs*

*   Avoid disabling errors on the PostgreSQL connection when enabling the
    `standard_conforming_strings` setting. Errors were previously disabled because
    the setting wasn't writable in Postgres 8.1 and didn't exist in earlier
    versions. Now Rails only supports Postgres 8.2+ we're fine to assume the
    setting exists. Disabling errors caused problems when using a connection
    pooling tool like PgBouncer because it's not guaranteed to have the same
    connection between calls to `execute` and it could leave the connection
    with errors disabled.

    Fixes #22101.

    *Harry Marr*

*   Set `scope.reordering_value` to `true` if `:reordering`-values are specified.

    Fixes #21886.

    *Hiroaki Izu*

*   Add support for bidirectional destroy dependencies.

    Fixes #13609.

    Example:

        class Content < ActiveRecord::Base
          has_one :position, dependent: :destroy
        end

        class Position < ActiveRecord::Base
          belongs_to :content, dependent: :destroy
        end

    *Seb Jacobs*

*   Includes HABTM returns correct size now. It's caused by the join dependency
    only instantiates one HABTM object because the join table hasn't a primary key.

    Fixes #16032.

    Examples:

        before:

        Project.first.salaried_developers.size # => 3
        Project.includes(:salaried_developers).first.salaried_developers.size # => 1

        after:

        Project.first.salaried_developers.size # => 3
        Project.includes(:salaried_developers).first.salaried_developers.size # => 3

    *Bigxiang*

*   Add option to index errors in nested attributes.

    For models which have nested attributes, errors within those models will
    now be indexed if `:index_errors` option is set to true when defining a
    `has_many` relationship or by setting the configuration option
    `config.active_record.index_nested_attribute_errors` to true.

    Example:

        class Guitar < ActiveRecord::Base
          has_many :tuning_pegs, index_errors: true
          accepts_nested_attributes_for :tuning_pegs
        end

        class TuningPeg < ActiveRecord::Base
          belongs_to :guitar
          validates_numericality_of :pitch
        end

        # Before
        guitar.errors["tuning_pegs.pitch"] = ["is not a number"]

        # After
        guitar.errors["tuning_pegs[1].pitch"] = ["is not a number"]

    *Michael Probber*, *Terence Sun*

*   Exit with non-zero status for failed database rake tasks.

    *Jay Hayes*

*   Queries such as `Computer.joins(:monitor).group(:status).count` will now be
    interpreted as  `Computer.joins(:monitor).group('computers.status').count`
    so that when `Computer` and `Monitor` have both `status` columns we don't
    have conflicts in projection.

    *Rafael Sales*

*   Add ability to default to `uuid` as primary key when generating database migrations.

    Example:

        config.generators do |g|
          g.orm :active_record, primary_key_type: :uuid
        end

    *Jon McCartie*

*   Don't cache arguments in `#find_by` if they are an `ActiveRecord::Relation`.

    Fixes #20817.

    *Hiroaki Izu*

*   Qualify column name inserted by `group` in calculation.

    Giving `group` an unqualified column name now works, even if the relation
    has `JOIN` with another table which also has a column of the name.

    *Soutaro Matsumoto*

*   Don't cache prepared statements containing an IN clause or a SQL literal, as
    these queries will change often and are unlikely to have a cache hit.

    *Sean Griffin*

*   Fix `rewhere` in a `has_many` association.

    Fixes #21955.

    *Josh Branchaud*, *Kal*

*   `where` raises ArgumentError on unsupported types.

    Fixes #20473.

    *Jake Worth*

*   Add an immutable string type to help reduce memory usage for apps which do
    not need mutation detection on strings.

    *Sean Griffin*

*   Give `ActiveRecord::Relation#update` its own deprecation warning when
    passed an `ActiveRecord::Base` instance.

    Fixes #21945.

    *Ted Johansson*

*   Make it possible to pass `:to_table` when adding a foreign key through
    `add_reference`.

    Fixes #21563.

    *Yves Senn*

*   No longer pass deprecated option `-i` to `pg_dump`.

    *Paul Sadauskas*

*   Concurrent `AR::Base#increment!` and `#decrement!` on the same record
    are all reflected in the database rather than overwriting each other.

    *Bogdan Gusiev*

*   Avoid leaking the first relation we call `first` on, per model.

    Fixes #21921.

    *Matthew Draper*, *Jean Boussier*

*   Remove unused `pk_and_sequence_for` in `AbstractMysqlAdapter`.

    *Ryuta Kamizono*

*   Allow fixtures files to set the model class in the YAML file itself.

    To load the fixtures file `accounts.yml` as the `User` model, use:

        _fixture:
          model_class: User
        david:
          name: David

    Fixes #9516.

    *Roque Pinel*

*   Don't require a database connection to load a class which uses acceptance
    validations.

    *Sean Griffin*

*   Correctly apply `unscope` when preloading through associations.

    *Jimmy Bourassa*

*   Fixed taking precision into count when assigning a value to timestamp attribute.

    Timestamp column can have less precision than ruby timestamp
    In result in how big a fraction of a second can be stored in the
    database.


        m = Model.create!
        m.created_at.usec == m.reload.created_at.usec # => false
        # due to different precision in Time.now and database column

    If the precision is low enough, (mysql default is 0, so it is always low
    enough by default) the value changes when model is reloaded from the
    database. This patch fixes that issue ensuring that any timestamp
    assigned as an attribute is converted to column precision under the
    attribute.

    *Bogdan Gusiev*

*   Introduce `connection.data_sources` and `connection.data_source_exists?`.
    These methods determine what relations can be used to back Active Record
    models (usually tables and views).

    Also deprecate `SchemaCache#tables`, `SchemaCache#table_exists?` and
    `SchemaCache#clear_table_cache!` in favor of their new data source
    counterparts.

    *Yves Senn*, *Matthew Draper*

*   Add `ActiveRecord::Base.ignored_columns` to make some columns
    invisible from Active Record.

    *Jean Boussier*

*   `ActiveRecord::Tasks::MySQLDatabaseTasks` fails if shellout to
    mysql commands (like `mysqldump`) is not successful.

    *Steve Mitchell*

*   Ensure `select` quotes aliased attributes, even when using `from`.

    Fixes #21488.

    *Sean Griffin*, *@johanlunds*

*   MySQL: support `unsigned` numeric data types.

    Example:

        create_table :foos do |t|
          t.unsigned_integer :quantity
          t.unsigned_bigint  :total
          t.unsigned_float   :percentage
          t.unsigned_decimal :price, precision: 10, scale: 2
        end

    The `unsigned: true` option may be used for the primary key:

        create_table :foos, id: :bigint, unsigned: true do |t|
          …
        end

    *Ryuta Kamizono*

*   Add `#views` and `#view_exists?` methods on connection adapters.

    *Ryuta Kamizono*

*   Correctly dump composite primary key.

    Example:

        create_table :barcodes, primary_key: ["region", "code"] do |t|
          t.string :region
          t.integer :code
        end

    *Ryuta Kamizono*

*   Lookup the attribute name for `restrict_with_error` messages on the
    model class that defines the association.

    *kuboon*, *Ronak Jangir*

*   Correct query for PostgreSQL 8.2 compatibility.

    *Ben Murphy*, *Matthew Draper*

*   `bin/rails db:migrate` uses
    `ActiveRecord::Tasks::DatabaseTasks.migrations_paths` instead of
    `Migrator.migrations_paths`.

    *Tobias Bielohlawek*

*   Support dropping indexes concurrently in PostgreSQL.

    See http://www.postgresql.org/docs/9.4/static/sql-dropindex.html for more
    details.

    *Grey Baker*

*   Deprecate passing conditions to `ActiveRecord::Relation#delete_all`
    and `ActiveRecord::Relation#destroy_all`.

    *Wojciech Wnętrzak*

*   Instantiating an AR model with `ActionController::Parameters` now raises
    an `ActiveModel::ForbiddenAttributesError` if the parameters include a
    `type` field that has not been explicitly permitted. Previously, the
    `type` field was simply ignored in the same situation.

    *Prem Sichanugrist*

*   PostgreSQL, `create_schema`, `drop_schema` and `rename_table` now quote
    schema names.

    Fixes #21418.

    Example:

        create_schema("my.schema")
        # CREATE SCHEMA "my.schema";

    *Yves Senn*

*   PostgreSQL, add `:if_exists` option to `#drop_schema`. This makes it
    possible to drop a schema that might exist without raising an exception if
    it doesn't.

    *Yves Senn*

*   Only try to nullify has_one target association if the record is persisted.

    Fixes #21223.

    *Agis Anastasopoulos*

*   Uniqueness validator raises descriptive error when running on a persisted
    record without primary key.

    Fixes #21304.

    *Yves Senn*

*   Add a native JSON data type support in MySQL.

    Example:

        create_table :json_data_type do |t|
          t.json :settings
        end

    *Ryuta Kamizono*

*   Descriptive error message when fixtures contain a missing column.

    Fixes #21201.

    *Yves Senn*

*   `ActiveRecord::Tasks::PostgreSQLDatabaseTasks` fail if shellout to
    postgresql commands (like `pg_dump`) is not successful.

    *Bryan Paxton*, *Nate Berkopec*

*   Add `ActiveRecord::Relation#in_batches` to work with records and relations
    in batches.

    Available options are `of` (batch size), `load`, `start`, and `finish`.

    Examples:

        Person.in_batches.each_record(&:party_all_night!)
        Person.in_batches.update_all(awesome: true)
        Person.in_batches.delete_all
        Person.in_batches.each do |relation|
          relation.delete_all
          sleep 10 # Throttles the delete queries
        end

    Fixes #20933.

    *Sina Siadat*

*   Added methods for PostgreSQL geometric data types to use in migrations.

    Example:

        create_table :foo do |t|
          t.line :foo_line
          t.lseg :foo_lseg
          t.box :foo_box
          t.path :foo_path
          t.polygon :foo_polygon
          t.circle :foo_circle
        end

    *Mehmet Emin İNAÇ*

*   Add `cache_key` to `ActiveRecord::Relation`.

    Example:

        @users = User.where("name like ?", "%Alberto%")
        @users.cache_key
        # => "/users/query-5942b155a43b139f2471b872ac54251f-3-20150714212107656125000"

    *Alberto Fernández-Capel*

*   Properly allow uniqueness validations on primary keys.

    Fixes #20966.

    *Sean Griffin*, *presskey*

*   Don't raise an error if an association failed to destroy when `destroy` was
    called on the parent (as opposed to `destroy!`).

    Fixes #20991.

    *Sean Griffin*

*   `ActiveRecord::RecordNotFound` modified to store model name, primary_key and
    id of the caller model. It allows the catcher of this exception to make
    a better decision to what to do with it.

    Example:

        class SomeAbstractController < ActionController::Base
          rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_404

          private def redirect_to_404(e)
            return redirect_to(posts_url) if e.model == 'Post'
            raise
          end
        end

    *Sameer Rahmani*

*   Deprecate the keys for association `restrict_dependent_destroy` errors in favor
    of new key names.

    Previously `has_one` and `has_many` associations were using the
    `one` and `many` keys respectively. Both of these keys have special
    meaning in I18n (they are considered to be pluralizations) so by
    renaming them to `has_one` and `has_many` we make the messages more explicit
    and most importantly they don't clash with linguistical systems that need to
    validate translation keys (and their pluralizations).

    The `:'restrict_dependent_destroy.one'` key should be replaced with
    `:'restrict_dependent_destroy.has_one'`, and `:'restrict_dependent_destroy.many'`
    with `:'restrict_dependent_destroy.has_many'`.

    *Roque Pinel*, *Christopher Dell*

*   Fix state being carried over from previous transaction.

    Considering the following example where `name` is a required attribute.
    Before we had `new_record?` returning `true` for a persisted record:

        author = Author.create! name: 'foo'
        author.name = nil
        author.save        # => false
        author.new_record? # => true

    Fixes #20824.

    *Roque Pinel*

*   Correctly ignore `mark_for_destruction` when `autosave` isn't set to `true`
    when validating associations.

    Fixes #20882.

    *Sean Griffin*

*   Fix a bug where counter_cache doesn't always work with polymorphic
    relations.

    Fixes #16407.

    *Stefan Kanev*, *Sean Griffin*

*   Ensure that cyclic associations with autosave don't cause duplicate errors
    to be added to the parent record.

    Fixes #20874.

    *Sean Griffin*

*   Ensure that `ActionController::Parameters` can still be passed to nested
    attributes.

    Fixes #20922.

    *Sean Griffin*

*   Deprecate force association reload by passing a truthy argument to
    association method.

    For collection association, you can call `#reload` on association proxy to
    force a reload:

        @user.posts.reload   # Instead of @user.posts(true)

    For singular association, you can call `#reload` on the parent object to
    clear its association cache then call the association method:

        @user.reload.profile   # Instead of @user.profile(true)

    Passing a truthy argument to force association to reload will be removed in
    Rails 5.1.

    *Prem Sichanugrist*

*   Replaced `ActiveSupport::Concurrency::Latch` with `Concurrent::CountDownLatch`
    from the concurrent-ruby gem.

    *Jerry D'Antonio*

*   Fix through associations using scopes having the scope merged multiple
    times.

    Fixes #20721.
    Fixes #20727.

    *Sean Griffin*

*   `ActiveRecord::Base.dump_schema_after_migration` applies migration tasks
    other than `db:migrate`. (eg. `db:rollback`, `db:migrate:dup`, ...)

    Fixes #20743.

    *Yves Senn*

*   Add alternate syntax to make `change_column_default` reversible.

    User can pass in `:from` and `:to` to make `change_column_default` command
    become reversible.

    Example:

        change_column_default :posts, :status, from: nil, to: "draft"
        change_column_default :users, :authorized, from: true, to: false

    *Prem Sichanugrist*

*   Prevent error when using `force_reload: true` on an unassigned polymorphic
    belongs_to association.

    Fixes #20426.

    *James Dabbs*

*   Correctly raise `ActiveRecord::AssociationTypeMismatch` when assigning
    a wrong type to a namespaced association.

    Fixes #20545.

    *Diego Carrion*

*   `validates_absence_of` respects `marked_for_destruction?`.

    Fixes #20449.

    *Yves Senn*

*   Include the `Enumerable` module in `ActiveRecord::Relation`

    *Sean Griffin*, *bogdan*

*   Use `Enumerable#sum` in `ActiveRecord::Relation` if a block is given.

    *Sean Griffin*

*   Let `WITH` queries (Common Table Expressions) be explainable.

    *Vladimir Kochnev*

*   Make `remove_index :table, :column` reversible.

    *Yves Senn*

*   Fixed an error which would occur in dirty checking when calling
    `update_attributes` from a getter.

    Fixes #20531.

    *Sean Griffin*

*   Make `remove_foreign_key` reversible. Any foreign key options must be
    specified, similar to `remove_column`.

    *Aster Ryan*

*   Add `:_prefix` and `:_suffix` options to `enum` definition.

    Fixes #17511, #17415.

    *Igor Kapkov*

*   Correctly handle decimal arrays with defaults in the schema dumper.

    Fixes #20515.

    *Sean Griffin*, *jmondo*

*   Deprecate the PostgreSQL `:point` type in favor of a new one which will return
    `Point` objects instead of an `Array`

    *Sean Griffin*

*   Ensure symbols passed to `ActiveRecord::Relation#select` are always treated
    as columns.

    Fixes #20360.

    *Sean Griffin*

*   Do not set `sql_mode` if `strict: :default` is specified.

        # config/database.yml
        production:
          adapter: mysql2
          database: foo_prod
          user: foo
          strict: :default

    *Ryuta Kamizono*

*   Allow proc defaults to be passed to the attributes API. See documentation
    for examples.

    *Sean Griffin*, *Kir Shatrov*

*   SQLite: `:collation` support for string and text columns.

    Example:

        create_table :foo do |t|
          t.string :string_nocase, collation: 'NOCASE'
          t.text :text_rtrim, collation: 'RTRIM'
        end

        add_column :foo, :title, :string, collation: 'RTRIM'

        change_column :foo, :title, :string, collation: 'NOCASE'

    *Akshay Vishnoi*

*   Allow the use of symbols or strings to specify enum values in test
    fixtures:

        awdr:
          title: "Agile Web Development with Rails"
          status: :proposed

    *George Claghorn*

*   Clear query cache when `ActiveRecord::Base#reload` is called.

    *Shane Hender, Pierre Nespo*

*   Include stored procedures and function on the MySQL structure dump.

    *Jonathan Worek*

*   Pass `:extend` option for `has_and_belongs_to_many` associations to the
    underlying `has_many :through`.

    *Jaehyun Shin*

*   Deprecate `Relation#uniq` use `Relation#distinct` instead.

    See #9683.

    *Yves Senn*

*   Allow single table inheritance instantiation to work when storing
    demodulized class names.

    *Alex Robbin*

*   Correctly pass MySQL options when using `structure_dump` or
    `structure_load`.

    Specifically, it fixes an issue when using SSL authentication.

    *Alex Coomans*

*   Correctly dump `:options` on `create_table` for MySQL.

    *Ryuta Kamizono*

*   PostgreSQL: `:collation` support for string and text columns.

    Example:

        create_table :foos do |t|
          t.string :string_en, collation: 'en_US.UTF-8'
          t.text   :text_ja,   collation: 'ja_JP.UTF-8'
        end

    *Ryuta Kamizono*

*   Remove `ActiveRecord::Serialization::XmlSerializer` from core.

    *Zachary Scott*

*   Make `unscope` aware of "less than" and "greater than" conditions.

    *TAKAHASHI Kazuaki*

*   `find_by` and `find_by!` raise `ArgumentError` when called without
    arguments.

    *Kohei Suzuki*

*   Revert behavior of `db:schema:load` back to loading the full
    environment. This ensures that initializers are run.

    Fixes #19545.

    *Yves Senn*

*   Fix missing index when using `timestamps` with the `index` option.

    The `index` option used with `timestamps` should be passed to both
    `column` definitions for `created_at` and `updated_at` rather than just
    the first.

    *Paul Mucur*

*   Rename `:class` to `:anonymous_class` in association options.

    Fixes #19659.

    *Andrew White*

*   Autosave existing records on a has many through association when the parent
    is new.

    Fixes #19782.

    *Sean Griffin*

*   Fixed a bug where uniqueness validations would error on out of range values,
    even if an validation should have prevented it from hitting the database.

    *Andrey Voronkov*

*   MySQL: `:charset` and `:collation` support for string and text columns.

    Example:

        create_table :foos do |t|
          t.string :string_utf8_bin, charset: 'utf8', collation: 'utf8_bin'
          t.text   :text_ascii,      charset: 'ascii'
        end

    *Ryuta Kamizono*

*   Foreign key related methods in the migration DSL respect
    `ActiveRecord::Base.pluralize_table_names = false`.

    Fixes #19643.

    *Mehmet Emin İNAÇ*

*   Reduce memory usage from loading types on PostgreSQL.

    Fixes #19578.

    *Sean Griffin*

*   Add `config.active_record.warn_on_records_fetched_greater_than` option.

    When set to an integer, a warning will be logged whenever a result set
    larger than the specified size is returned by a query.

    Fixes #16463.

    *Jason Nochlin*

*   Ignore `.psqlrc` when loading database structure.

    *Jason Weathered*

*   Fix referencing wrong table aliases while joining tables of has many through
    association (only when calling calculation methods).

    Fixes #19276.

    *pinglamb*

*   Correctly persist a serialized attribute that has been returned to
    its default value by an in-place modification.

    Fixes #19467.

    *Matthew Draper*

*   Fix generating the schema file when using PostgreSQL `BigInt[]` data type.
    Previously the `limit: 8` was not coming through, and this caused it to
    become `Int[]` data type after rebuilding from the schema.

    Fixes #19420.

    *Jake Waller*

*   Reuse the `CollectionAssociation#reader` cache when the foreign key is
    available prior to save.

    *Ben Woosley*

*   Add `config.active_record.dump_schemas` to fix `db:structure:dump`
    when using schema_search_path and PostgreSQL extensions.

    Fixes #17157.

    *Ryan Wallace*

*   Renaming `use_transactional_fixtures` to `use_transactional_tests` for clarity.

    Fixes #18864.

    *Brandon Weiss*

*   Increase pg gem version requirement to `~> 0.18`. Earlier versions of the
    pg gem are known to have problems with Ruby 2.2.

    *Matt Brictson*

*   Correctly dump `serial` and `bigserial`.

    *Ryuta Kamizono*

*   Fix default `format` value in `ActiveRecord::Tasks::DatabaseTasks#schema_file`.

    *James Cox*

*   Don't enroll records in the transaction if they don't have commit callbacks.
    This was causing a memory leak when creating many records inside a transaction.

    Fixes #15549.

    *Will Bryant*, *Aaron Patterson*

*   Correctly create through records when created on a has many through
    association when using `where`.

    Fixes #19073.

    *Sean Griffin*

*   Add `SchemaMigration.create_table` support for any unicode charsets with MySQL.

    *Ryuta Kamizono*

*   PostgreSQL no longer disables user triggers if system triggers can't be
    disabled. Disabling user triggers does not fulfill what the method promises.
    Rails currently requires superuser privileges for this method.

    If you absolutely rely on this behavior, consider patching
    `disable_referential_integrity`.

    *Yves Senn*

*   Restore aborted transaction state when `disable_referential_integrity` fails
    due to missing permissions.

    *Toby Ovod-Everett*, *Yves Senn*

*   In PostgreSQL, print a warning message if `disable_referential_integrity`
    fails due to missing permissions.

    *Andrey Nering*, *Yves Senn*

*   Allow a `:limit` option for MySQL bigint primary key support.

    Example:

        create_table :foos, id: :primary_key, limit: 8 do |t|
        end

        # or

        create_table :foos, id: false do |t|
          t.primary_key :id, limit: 8
        end

    *Ryuta Kamizono*

*   `belongs_to` will now trigger a validation error by default if the association is not present.
    You can turn this off on a per-association basis with `optional: true`.
    (Note this new default only applies to new Rails apps that will be generated with
    `config.active_record.belongs_to_required_by_default = true` in initializer.)

    *Josef Šimánek*

*   Fixed `ActiveRecord::Relation#becomes!` and `changed_attributes` issues for type
    columns.

    Fixes #17139.

    *Miklos Fazekas*

*   Format the time string according to the precision of the time column.

    *Ryuta Kamizono*

*   Allow a `:precision` option for time type columns.

    *Ryuta Kamizono*

*   Add `ActiveRecord::Base.suppress` to prevent the receiver from being saved
    during the given block.

    For example, here's a pattern of creating notifications when new comments
    are posted. (The notification may in turn trigger an email, a push
    notification, or just appear in the UI somewhere):

        class Comment < ActiveRecord::Base
          belongs_to :commentable, polymorphic: true
          after_create -> { Notification.create! comment: self,
            recipients: commentable.recipients }
        end

    That's what you want the bulk of the time. A new comment creates a new
    Notification. There may be edge cases where you don't want that, like
    when copying a commentable and its comments, in which case write a
    concern with something like this:

        module Copyable
          def copy_to(destination)
            Notification.suppress do
              # Copy logic that creates new comments that we do not want triggering
              # notifications.
            end
          end
        end

    *Michael Ryan*

*   `:time` option added for `#touch`.

    Fixes #18905.

    *Hyonjee Joo*

*   Add `foreign_key_exists?` method.

    *Tõnis Simo*

*   Use SQL COUNT and LIMIT 1 queries for `none?` and `one?` methods
    if no block or limit is given, instead of loading the entire
    collection into memory. This applies to relations (e.g. `User.all`)
    as well as associations (e.g. `account.users`)

        # Before:

        users.none?
        # SELECT "users".* FROM "users"

        users.one?
        # SELECT "users".* FROM "users"

        # After:

        users.none?
        # SELECT 1 AS one FROM "users" LIMIT 1

        users.one?
        # SELECT COUNT(*) FROM "users"

    *Eugene Gilburg*

*   Have `enum` perform type casting consistently with the rest of Active
    Record, such as `where`.

    *Sean Griffin*

*   `scoping` no longer pollutes the current scope of sibling classes when using
    STI.

    Fixes #18806.

    Example:

        StiOne.none.scoping do
          StiTwo.all
        end


    *Sean Griffin*

*   `remove_reference` with `foreign_key: true` removes the foreign key before
    removing the column. This fixes a bug where it was not possible to remove
    the column on MySQL.

    Fixes #18664.

    *Yves Senn*

*   `find_in_batches` now accepts an `:finish` parameter that complements the `:start`
     parameter to specify where to stop batch processing.

    *Vipul A M*

*   Fix a rounding problem for PostgreSQL timestamp columns.

    If a timestamp column has a precision specified, it needs to
    format according to that.

    *Ryuta Kamizono*

*   Respect the database default charset for `schema_migrations` table.

    The charset of `version` column in `schema_migrations` table depends
    on the database default charset and collation rather than the encoding
    of the connection.

    *Ryuta Kamizono*

*   Raise `ArgumentError` when passing `nil` or `false` to `Relation#merge`.

    These are not valid values to merge in a relation, so it should warn users
    early.

    *Rafael Mendonça França*

*   Use `SCHEMA` instead of `DB_STRUCTURE` for specifying a structure file.

    This makes the `db:structure` tasks consistent with `test:load_structure`.

    *Dieter Komendera*

*   Respect custom primary keys for associations when calling `Relation#where`

    Fixes #18813.

    *Sean Griffin*

*   Fix several edge cases which could result in a counter cache updating
    twice or not updating at all for `has_many` and `has_many :through`.

    Fixes #10865.

    *Sean Griffin*

*   Foreign keys added by migrations were given random, generated names. This
    meant a different `structure.sql` would be generated every time a developer
    ran migrations on their machine.

    The generated part of foreign key names is now a hash of the table name and
    column name, which is consistent every time you run the migration.

    *Chris Sinjakli*

*   Fix n+1 query problem when eager loading nil associations (fixes #18312)

    *Sammy Larbi*

*   Change the default error message from `can't be blank` to `must exist` for
    the presence validator of the `:required` option on `belongs_to`/`has_one`
    associations.

    *Henrik Nygren*

*   Fixed `ActiveRecord::Relation#group` method when an argument is an SQL
    reserved keyword:

    Example:

        SplitTest.group(:key).count
        Property.group(:value).count

    *Bogdan Gusiev*

*   Added the `#or` method on `ActiveRecord::Relation`, allowing use of the OR
    operator to combine WHERE or HAVING clauses.

    Example:

        Post.where('id = 1').or(Post.where('id = 2'))
        # => SELECT * FROM posts WHERE (id = 1) OR (id = 2)

    *Sean Griffin*, *Matthew Draper*, *Gael Muller*, *Olivier El Mekki*

*   Don't define autosave association callbacks twice from
    `accepts_nested_attributes_for`.

    Fixes #18704.

    *Sean Griffin*

*   Integer types will no longer raise a `RangeError` when assigning an
    attribute, but will instead raise when going to the database.

    Fixes several vague issues which were never reported directly. See the
    commit message from the commit which added this line for some examples.

    *Sean Griffin*

*   Values which would error while being sent to the database (such as an
    ASCII-8BIT string with invalid UTF-8 bytes on SQLite3), no longer error on
    assignment. They will still error when sent to the database, but you are
    given the ability to re-assign it to a valid value.

    Fixes #18580.

    *Sean Griffin*

*   Don't remove join dependencies in `Relation#exists?`

    Fixes #18632.

    *Sean Griffin*

*   Invalid values assigned to a JSON column are assumed to be `nil`.

    Fixes #18629.

    *Sean Griffin*

*   Add `ActiveRecord::Base#accessed_fields`, which can be used to quickly
    discover which fields were read from a model when you are looking to only
    select the data you need from the database.

    *Sean Griffin*

*   Introduce the `:if_exists` option for `drop_table`.

    Example:

        drop_table(:posts, if_exists: true)

    That would execute:

        DROP TABLE IF EXISTS posts

    If the table doesn't exist, `if_exists: false` (the default) raises an
    exception whereas `if_exists: true` does nothing.

    *Cody Cutrer*, *Stefan Kanev*, *Ryuta Kamizono*

*   Don't run SQL if attribute value is not changed for update_attribute method.

    *Prathamesh Sonpatki*

*   `time` columns can now get affected by `time_zone_aware_attributes`. If you have
    set `config.time_zone` to a value other than `'UTC'`, they will be treated
    as in that time zone by default in Rails 5.1. If this is not the desired
    behavior, you can set

        ActiveRecord::Base.time_zone_aware_types = [:datetime]

    A deprecation warning will be emitted if you have a `:time` column, and have
    not explicitly opted out.

    Fixes #3145.

    *Sean Griffin*

*   Tests now run after_commit callbacks. You no longer have to declare
    `uses_transaction ‘test name’` to test the results of an after_commit.

    after_commit callbacks run after committing a transaction whose parent
    is not `joinable?`: un-nested transactions, transactions within test cases,
    and transactions in `console --sandbox`.

    *arthurnn*, *Ravil Bayramgalin*, *Matthew Draper*

*   `nil` as a value for a binary column in a query no longer logs as
    "<NULL binary data>", and instead logs as just "nil".

    *Sean Griffin*

*   `attribute_will_change!` will no longer cause non-persistable attributes to
    be sent to the database.

    Fixes #18407.

    *Sean Griffin*

*   Remove support for the `protected_attributes` gem.

    *Carlos Antonio da Silva*, *Roberto Miranda*

*   Fix accessing of fixtures having non-string labels like Fixnum.

    *Prathamesh Sonpatki*

*   Remove deprecated support to preload instance-dependent associations.

    *Yves Senn*

*   Remove deprecated support for PostgreSQL ranges with exclusive lower bounds.

    *Yves Senn*

*   Remove deprecation when modifying a relation with cached Arel.
    This raises an `ImmutableRelation` error instead.

    *Yves Senn*

*   Added `ActiveRecord::SecureToken` in order to encapsulate generation of
    unique tokens for attributes in a model using `SecureRandom`.

    *Roberto Miranda*

*   Change the behavior of boolean columns to be closer to Ruby's semantics.

    Before this change we had a small set of "truthy", and all others are "falsy".

    Now, we have a small set of "falsy" values and all others are "truthy" matching
    Ruby's semantics.

    *Rafael Mendonça França*

*   Deprecate `ActiveRecord::Base.errors_in_transactional_callbacks=`.

    *Rafael Mendonça França*

*   Change transaction callbacks to not swallow errors.

    Before this change any errors raised inside a transaction callback
    were getting rescued and printed in the logs.

    Now these errors are not rescued anymore and just bubble up, as the other callbacks.

    *Rafael Mendonça França*

*   Remove deprecated `sanitize_sql_hash_for_conditions`.

    *Rafael Mendonça França*

*   Remove deprecated `Reflection#source_macro`.

    *Rafael Mendonça França*

*   Remove deprecated `symbolized_base_class` and `symbolized_sti_name`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.disable_implicit_join_references=`.

    *Rafael Mendonça França*

*   Remove deprecated access to connection specification using a string accessor.

    Now all strings will be handled as a URL.

    *Rafael Mendonça França*

*   Change the default `null` value for `timestamps` to `false`.

    *Rafael Mendonça França*

*   Return an array of pools from `connection_pools`.

    *Rafael Mendonça França*

*   Return a null column from `column_for_attribute` when no column exists.

    *Rafael Mendonça França*

*   Remove deprecated `serialized_attributes`.

    *Rafael Mendonça França*

*   Remove deprecated automatic counter caches on `has_many :through`.

    *Rafael Mendonça França*

*   Change the way in which callback chains can be halted.

    The preferred method to halt a callback chain from now on is to explicitly
    `throw(:abort)`.
    In the past, returning `false` in an Active Record `before_` callback had the
    side effect of halting the callback chain.
    This is not recommended anymore and, depending on the value of the
    `ActiveSupport.halt_callback_chains_on_return_false` option, will
    either not work at all or display a deprecation warning.

    *claudiob*

*   Clear query cache on rollback.

    *Florian Weingarten*

*   Fix setting of foreign_key for through associations when building a new record.

    Fixes #12698.

    *Ivan Antropov*

*   Improve dumping of the primary key. If it is not a default primary key,
    correctly dump the type and options.

    Fixes #14169, #16599.

    *Ryuta Kamizono*

*   Format the datetime string according to the precision of the datetime field.

    Incompatible to rounding behavior between MySQL 5.6 and earlier.

    In 5.5, when you insert `2014-08-17 12:30:00.999999` the fractional part
    is ignored. In 5.6, it's rounded to `2014-08-17 12:30:01`:

    http://bugs.mysql.com/bug.php?id=68760

    *Ryuta Kamizono*

*   Allow a precision option for MySQL datetimes.

    *Ryuta Kamizono*

*   Fixed automatic `inverse_of` for models nested in a module.

    *Andrew McCloud*

*   Change `ActiveRecord::Relation#update` behavior so that it can
    be called without passing ids of the records to be updated.

    This change allows updating multiple records returned by
    `ActiveRecord::Relation` with callbacks and validations.

        # Before
        # ArgumentError: wrong number of arguments (1 for 2)
        Comment.where(group: 'expert').update(body: "Group of Rails Experts")

        # After
        # Comments with group expert updated with body "Group of Rails Experts"
        Comment.where(group: 'expert').update(body: "Group of Rails Experts")

    *Prathamesh Sonpatki*

*   Fix `reaping_frequency` option when the value is a string.

    This usually happens when it is configured using `DATABASE_URL`.

    *korbin*

*   Fix error message when trying to create an associated record and the foreign
    key is missing.

    Before this fix the following exception was being raised:

        NoMethodError: undefined method `val' for #<Arel::Nodes::BindParam:0x007fc64d19c218>

    Now the message is:

        ActiveRecord::UnknownAttributeError: unknown attribute 'foreign_key' for Model.

    *Rafael Mendonça França*

*   Fix change detection problem for PostgreSQL bytea type and
    `ArgumentError: string contains null byte` exception with pg-0.18.

    Fixes #17680.

    *Lars Kanis*

*   When a table has a composite primary key, the `primary_key` method for
    SQLite3 and PostgreSQL adapters was only returning the first field of the key.
    Ensures that it will return nil instead, as Active Record doesn't support
    composite primary keys.

    Fixes #18070.

    *arthurnn*

*   `validates_size_of` / `validates_length_of` do not count records
    which are `marked_for_destruction?`.

    Fixes #7247.

    *Yves Senn*

*   Ensure `first!` and friends work on loaded associations.

    Fixes #18237.

    *Sean Griffin*

*   `eager_load` preserves readonly flag for associations.

    Fixes #15853.

    *Takashi Kokubun*

*   Provide `:touch` option to `save()` to accommodate saving without updating
    timestamps.

    Fixes #18202.

    *Dan Olson*

*   Provide a more helpful error message when an unsupported class is passed to
    `serialize`.

    Fixes #18224.

    *Sean Griffin*

*   Add bigint primary key support for MySQL.

    Example:

        create_table :foos, id: :bigint do |t|
        end

    *Ryuta Kamizono*

*   Support for any type of primary key.

    Fixes #14194.

    *Ryuta Kamizono*

*   Dump the default `nil` for PostgreSQL UUID primary key.

    *Ryuta Kamizono*

*   Add a `:foreign_key` option to `references` and associated migration
    methods. The model and migration generators now use this option, rather than
    the `add_foreign_key` form.

    *Sean Griffin*

*   Don't raise when writing an attribute with an out-of-range datetime passed
    by the user.

    *Grey Baker*

*   Replace deprecated `ActiveRecord::Tasks::DatabaseTasks#load_schema` with
    `ActiveRecord::Tasks::DatabaseTasks#load_schema_for`.

    *Yves Senn*

*   Fix bug with `ActiveRecord::Type::Numeric` that caused negative values to
    be marked as having changed when set to the same negative value.

    Fixes #18161.

    *Daniel Fox*

*   Introduce `force: :cascade` option for `create_table`. Using this option
    will recreate tables even if they have dependent objects (like foreign keys).
    `db/schema.rb` now uses `force: :cascade`. This makes it possible to
    reload the schema when foreign keys are in place.

    *Matthew Draper*, *Yves Senn*

*   `db:schema:load` and `db:structure:load` no longer purge the database
    before loading the schema. This is left for the user to do.
    `db:test:prepare` will still purge the database.

    Fixes #17945.

    *Yves Senn*

*   Fix undesirable RangeError by `Type::Integer`. Add `Type::UnsignedInteger`.

    *Ryuta Kamizono*

*   Add `foreign_type` option to `has_one` and `has_many` association macros.

    This option enables to define the column name of associated object's type for polymorphic associations.

    *Ulisses Almeida*, *Kassio Borges*

*   Remove deprecated behavior allowing nested arrays to be passed as query
    values.

    *Melanie Gilman*

*   Deprecate passing a class as a value in a query. Users should pass strings
    instead.

    *Melanie Gilman*

*   `add_timestamps` and `remove_timestamps` now properly reversible with
    options.

    *Noam Gagliardi-Rabinovich*

*   `ActiveRecord::ConnectionAdapters::ColumnDumper#column_spec` and
    `ActiveRecord::ConnectionAdapters::ColumnDumper#prepare_column_options` no
    longer have a `types` argument. They should access
    `connection#native_database_types` directly.

    *Yves Senn*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activerecord/CHANGELOG.md) for previous changes.
