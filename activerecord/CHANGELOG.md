## Rails 3.2.9 (unreleased)

*   `CollectionAssociation#count` returns 0 without querying if the
    parent record is new.

    Before:

        person.pets
        # SELECT COUNT(*) FROM "pets" WHERE "pets"."person_id" IS NULL
        # => 0

    After:

        person.pets
        # fires without sql query
        # => 0

    *Francesco Rodriguez*

*   Fix `reset_counters` crashing on `has_many :through` associations.
    Fix #7822.

    *lulalala*

*   ConnectionPool recognizes checkout_timeout spec key as taking
    precedence over legacy wait_timeout spec key, can be used to avoid
    conflict with mysql2 use of wait_timeout.  Closes #7684.

    *jrochkind*

*   Rename field_changed? to _field_changed? so that users can create a field named field

    *Akira Matsuda*, backported by *Steve Klabnik*

*   Fix creation of through association models when using `collection=[]`
    on a `has_many :through` association from an unsaved model.
    Fix #7661.

    *Ernie Miller*

*   Explain only normal CRUD sql (select / update / insert / delete).
    Fix problem that explains unexplainable sql. Closes #7544 #6458.

    *kennyj*

*   Backport test coverage to ensure that PostgreSQL auto-reconnect functionality
    remains healthy.

    *Steve Jorgensen*

*   Use config['encoding'] instead of config['charset'] when executing
    databases.rake in the mysql/mysql2. A correct option for a database.yml
    is 'encoding'.

    *kennyj*

*   Fix ConnectionAdapters::Column.type_cast_code integer conversion,
    to always convert values to integer calling #to_i. Fixes #7509.

    *Thiago Pradi*

*   Fix time column type casting for invalid time string values to correctly return nil.

    *Adam Meehan*

*   Fix `becomes` when using a configured `inheritance_column`.

    *Yves Senn*

*   Fix `reset_counters` when there are multiple `belongs_to` association with the
    same foreign key and one of them have a counter cache.
    Fixes #5200.

    *Dave Desrochers*

*   Round usec when comparing timestamp attributes in the dirty tracking.
    Fixes #6975.

    *kennyj*

*   Use inversed parent for first and last child of has_many association.

    *Ravil Bayramgalin*

*   Fix Column.microseconds and Column.fast_string_to_date to avoid converting
    timestamp seconds to a float, since it occasionally results in inaccuracies
    with microsecond-precision times. Fixes #7352.

    *Ari Pollak*

*   Fix `increment!`, `decrement!`, `toggle!` that was skipping callbacks.
    Fixes #7306.

    *Rafael Mendonça França*

*   Fix AR#create to return an unsaved record when AR::RecordInvalid is
    raised. Fixes #3217.

    *Dave Yeu*

*   Remove unnecessary transaction when assigning has_one associations with a nil or equal value.
    Fix #7191.

    *kennyj*

*   Allow store to work with an empty column.
    Fix #4840.

    *Jeremy Walker*

*   Remove prepared statement from system query in postgresql adapter.
    Fix #5872.

    *Ivan Evtuhovich*

*   Make sure `:environment` task is executed before `db:schema:load` or `db:structure:load`
    Fixes #4772.

    *Seamus Abshere*


## Rails 3.2.8 (Aug 9, 2012) ##

*   Do not consider the numeric attribute as changed if the old value is zero and the new value
    is not a string.
    Fixes #7237.

    *Rafael Mendonça França*

*   Removes the deprecation of `update_attribute`. *fxn*

*   Reverted the deprecation of `composed_of`. *Rafael Mendonça França*

*   Reverted the deprecation of `*_sql` association options. They will
    be deprecated in 4.0 instead. *Jon Leighton*

*   Do not eager load AR session store. ActiveRecord::SessionStore depends on the abstract store
    in Action Pack. Eager loading this class would break client code that eager loads Active Record
    standalone.
    Fixes #7160

    *Xavier Noria*

*   Do not set RAILS_ENV to "development" when using `db:test:prepare` and related rake tasks.
    This was causing the truncation of the development database data when using RSpec.
    Fixes #7175.

    *Rafael Mendonça França*

## Rails 3.2.7 (Jul 26, 2012) ##

*   `:finder_sql` and `:counter_sql` options on collection associations
    are deprecated. Please transition to using scopes.

    *Jon Leighton*

*   `:insert_sql` and `:delete_sql` options on `has_and_belongs_to_many`
    associations are deprecated. Please transition to using `has_many
    :through`

    *Jon Leighton*

*   `composed_of` has been deprecated. You'll have to write your own accessor
    and mutator methods if you'd like to use value objects to represent some
    portion of your models.

    *Steve Klabnik*

*   `update_attribute` has been deprecated. Use `update_column` if
    you want to bypass mass-assignment protection, validations, callbacks,
    and touching of updated_at. Otherwise please use `update_attributes`.

    *Steve Klabnik*

## Rails 3.2.6 (Jun 12, 2012) ##

*   protect against the nesting of hashes changing the
    table context in the next call to build_from_hash. This fix
    covers this case as well.

    CVE-2012-2695

*   Revert earlier 'perf fix' (see 3.2.4 changelog / GH #6289). This
    change introduced a regression (GH #6609). assoc.clear and
    assoc.delete_all have loaded the association before doing the delete
    since at least Rails 2.3. Doing the delete without loading the
    records means that the `before_remove` and `after_remove` callbacks do
    not get invoked. Therefore, this change was less a fix a more an
    optimisation, which should only have gone into master.

    *Jon Leighton*

## Rails 3.2.5 (Jun 1, 2012) ##

*   Restore behavior of Active Record 3.2.3 scopes.
    A series of commits relating to preloading and scopes caused a regression.

    *Andrew White*


## Rails 3.2.4 (May 31, 2012) ##

*   Perf fix: Don't load the records when doing assoc.delete_all.
    GH #6289. *Jon Leighton*

*   Association preloading shouldn't be affected by the current scoping.
    This could cause infinite recursion and potentially other problems.
    See GH #5667. *Jon Leighton*

*   Datetime attributes are forced to be changed. GH #3965

*   Fix attribute casting. GH #5549

*   Fix #5667. Preloading should ignore scoping.

*   Predicate builder should not recurse for determining where columns.
    Thanks to Ben Murphy for reporting this! CVE-2012-2661


## Rails 3.2.3 (March 30, 2012) ##

*   Added find_or_create_by_{attribute}! dynamic method. *Andrew White*

*   Whitelist all attribute assignment by default. Change the default for newly generated applications to whitelist all attribute assignment.  Also update the generated model classes so users are reminded of the importance of attr_accessible. *NZKoz*

*   Update ActiveRecord::AttributeMethods#attribute_present? to return false for empty strings. *Jacobkg*

*   Fix associations when using per class databases. *larskanis*

*   Revert setting NOT NULL constraints in add_timestamps *fxn*

*   Fix mysql to use proper text types. Fixes #3931. *kennyj*

*   Fix #5069 - Protect foreign key from mass assignment through association builder. *byroot*


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   The threshold for auto EXPLAIN is ignored if there's no logger. *fxn*

*   Call `to_s` on the value passed to `table_name=`, in particular symbols
    are supported (regression). *Sergey Nartimov*

*   Fix possible race condition when two threads try to define attribute
    methods for the same class. *Jon Leighton*


## Rails 3.2.0 (January 20, 2012) ##

*   Added a `with_lock` method to ActiveRecord objects, which starts
    a transaction, locks the object (pessimistically) and yields to the block.
    The method takes one (optional) parameter and passes it to `lock!`.

    Before:

        class Order < ActiveRecord::Base
          def cancel!
            transaction do
              lock!
              # ... cancelling logic
            end
          end
        end

    After:

        class Order < ActiveRecord::Base
          def cancel!
            with_lock do
              # ... cancelling logic
            end
          end
        end

    *Olek Janiszewski*

*   'on' and 'ON' boolean columns values are type casted to true
    *Santiago Pastorino*

*   Added ability to run migrations only for given scope, which allows
    to run migrations only from one engine (for example to revert changes
    from engine that you want to remove).

    Example:
      rake db:migrate SCOPE=blog

    *Piotr Sarnacki*

*   Migrations copied from engines are now scoped with engine's name,
    for example 01_create_posts.blog.rb. *Piotr Sarnacki*

*   Implements `AR::Base.silence_auto_explain`. This method allows the user to
    selectively disable automatic EXPLAINs within a block. *fxn*

*   Implements automatic EXPLAIN logging for slow queries.

    A new configuration parameter `config.active_record.auto_explain_threshold_in_seconds`
    determines what's to be considered a slow query. Setting that to `nil` disables
    this feature. Defaults are 0.5 in development mode, and `nil` in test and production
    modes.

    As of this writing there's support for SQLite, MySQL (mysql2 adapter), and
    PostgreSQL.

    *fxn*

*   Implemented ActiveRecord::Relation#pluck method

    Method returns Array of column value from table under ActiveRecord model

        Client.pluck(:id)

    *Bogdan Gusiev*

*   Automatic closure of connections in threads is deprecated.  For example
    the following code is deprecated:

    Thread.new { Post.find(1) }.join

    It should be changed to close the database connection at the end of
    the thread:

    Thread.new {
      Post.find(1)
      Post.connection.close
    }.join

    Only people who spawn threads in their application code need to worry
    about this change.

*   Deprecated:

      * `set_table_name`
      * `set_inheritance_column`
      * `set_sequence_name`
      * `set_primary_key`
      * `set_locking_column`

    Use an assignment method instead. For example, instead of `set_table_name`, use `self.table_name=`:

         class Project < ActiveRecord::Base
           self.table_name = "project"
         end

    Or define your own `self.table_name` method:

         class Post < ActiveRecord::Base
           def self.table_name
             "special_" + super
           end
         end
         Post.table_name # => "special_posts"

    *Jon Leighton*

*   Generated association methods are created within a separate module to allow overriding and
    composition using `super`. For a class named `MyModel`, the module is named
    `MyModel::GeneratedFeatureMethods`. It is included into the model class immediately after
    the `generated_attributes_methods` module defined in ActiveModel, so association methods
    override attribute methods of the same name. *Josh Susser*

*   Implemented ActiveRecord::Relation#explain. *fxn*

*   Add ActiveRecord::Relation#uniq for generating unique queries.

    Before:

        Client.select('DISTINCT name')

    After:

        Client.select(:name).uniq

    This also allows you to revert the unqueness in a relation:

        Client.select(:name).uniq.uniq(false)

    *Jon Leighton*

*   Support index sort order in sqlite, mysql and postgres adapters. *Vlad Jebelev*

*   Allow the :class_name option for associations to take a symbol (:Client) in addition to
    a string ('Client').

    This is to avoid confusing newbies, and to be consistent with the fact that other options
    like :foreign_key already allow a symbol or a string.

    *Jon Leighton*

*   In development mode the db:drop task also drops the test database. For symmetry with
    the db:create task. *Dmitriy Kiriyenko*

*   Added ActiveRecord::Base.store for declaring simple single-column key/value stores *DHH*

        class User < ActiveRecord::Base
          store :settings, accessors: [ :color, :homepage ]
        end

        u = User.new(color: 'black', homepage: '37signals.com')
        u.color                          # Accessor stored attribute
        u.settings[:country] = 'Denmark' # Any attribute, even if not specified with an accessor


*   MySQL: case-insensitive uniqueness validation avoids calling LOWER when
    the column already uses a case-insensitive collation. Fixes #561.

    *Joseph Palermo*

*   Transactional fixtures enlist all active database connections. You can test
    models on different connections without disabling transactional fixtures.

    *Jeremy Kemper*

*   Add first_or_create, first_or_create!, first_or_initialize methods to Active Record. This is a
    better approach over the old find_or_create_by dynamic methods because it's clearer which
    arguments are used to find the record and which are used to create it:

        User.where(:first_name => "Scarlett").first_or_create!(:last_name => "Johansson")

    *Andrés Mejía*

*   Fix nested attributes bug where _destroy parameter is taken into account
    during :reject_if => :all_blank (fixes #2937)

    *Aaron Christy*

*   Add ActiveSupport::Cache::NullStore for use in development and testing.

    *Brian Durand*

Please check [3-1-stable](https://github.com/rails/rails/blob/3-1-stable/activerecord/CHANGELOG.md) for previous changes.
