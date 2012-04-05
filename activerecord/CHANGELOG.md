## Rails 4.0.0 (unreleased) ##

*   Add STI support to init and building associations.
    Allows you to do BaseClass.new(:type => "SubClass") as well as
    parent.children.build(:type => "SubClass") or parent.build_child
    to initialize an STI subclass. Ensures that the class name is a
    valid class and that it is in the ancestors of the super class
    that the association is expecting.

    *Jason Rush*

*   Observers was extracted from Active Record as `rails-observers` gem.

    *Rafael Mendonça França*

*   Ensure that associations take a symbol argument. *Steve Klabnik*

*   Fix dirty attribute checks for `TimeZoneConversion` with nil and blank
    datetime attributes. Setting a nil datetime to a blank string should not
    result in a change being flagged. Fix #8310

    *Alisdair McDiarmid*

*   Prevent mass assignment to the type column of polymorphic associations when using `build`
    Fix #8265

    *Yves Senn*

*   Deprecate calling `Relation#sum` with a block. To perform a calculation over
    the array result of the relation, use `to_a.sum(&block)`.

    *Carlos Antonio da Silva*

*   Fix postgresql adapter to handle BC timestamps correctly

        HistoryEvent.create!(:name => "something", :occured_at => Date.new(0) - 5.years)

    *Bogdan Gusiev*

*   When running migrations on Postgresql, the `:limit` option for `binary` and `text` columns is silently dropped.
    Previously, these migrations caused sql exceptions, because Postgresql doesn't support limits on these types.

    *Victor Costan*

*   Don't change STI type when calling `ActiveRecord::Base#becomes`.
    Add `ActiveRecord::Base#becomes!` with the previous behavior.

    See #3023 for more information.

    *Thomas Hollstegge*

*   `rename_index` can be used inside a `change_table` block.

        change_table :accounts do |t|
          t.rename_index :user_id, :account_id
        end

    *Jarek Radosz*

*   `#pluck` can be used on a relation with `select` clause. Fix #7551

    Example:

        Topic.select([:approved, :id]).order(:id).pluck(:id)

    *Yves Senn*

*   Do not create useless database transaction when building `has_one` association.

    Example:

        User.has_one :profile
        User.new.build_profile

    *Bogdan Gusiev*

*   `:counter_cache` option for `has_many` associations to support custom named counter caches.
    Fix #7993

    *Yves Senn*

*   Deprecate the possibility to pass a string as third argument of `add_index`.
    Pass `unique: true` instead.

        add_index(:users, :organization_id, unique: true)

    *Rafael Mendonça França*

*   Raise an `ArgumentError` when passing an invalid option to `add_index`.

    *Rafael Mendonça França*

*   Fix `find_in_batches` crashing when IDs are strings and start option is not specified.

    *Alexis Bernard*

*   `AR::Base#attributes_before_type_cast` now returns unserialized values for serialized attributes.

    *Nikita Afanasenko*

*   Use query cache/uncache when using `DATABASE_URL`.
    Fix #6951.

    *kennyj*

*   Added `#none!` method for mutating `ActiveRecord::Relation` objects to a NullRelation.
    It acts like `#none` but modifies relation in place.

    *Juanjo Bazán*

*   Fix bug where `update_columns` and `update_column` would not let you update the primary key column.

    *Henrik Nyh*

*   The `create_table` method raises an `ArgumentError` when the primary key column is redefined.
    Fix #6378

    *Yves Senn*

*   `ActiveRecord::AttributeMethods#[]` raises `ActiveModel::MissingAttributeError`
    error if the given attribute is missing. Fixes #5433.

        class Person < ActiveRecord::Base
          belongs_to :company
        end

        # Before:
        person = Person.select('id').first
        person[:name]       # => nil
        person.name         # => ActiveModel::MissingAttributeError: missing_attribute: name
        person[:company_id] # => nil
        person.company      # => nil

        # After:
        person = Person.select('id').first
        person[:name]       # => ActiveModel::MissingAttributeError: missing_attribute: name
        person.name         # => ActiveModel::MissingAttributeError: missing_attribute: name
        person[:company_id] # => ActiveModel::MissingAttributeError: missing_attribute: company_id
        person.company      # => ActiveModel::MissingAttributeError: missing_attribute: company_id

    *Francesco Rodriguez*

*   Small binary fields use the `VARBINARY` MySQL type, instead of `TINYBLOB`.

    *Victor Costan*

*   Decode URI encoded attributes on database connection URLs.

    *Shawn Veader*

*   Add `find_or_create_by`, `find_or_create_by!` and
    `find_or_initialize_by` methods to `Relation`.

    These are similar to the `first_or_create` family of methods, but
    the behaviour when a record is created is slightly different:

        User.where(first_name: 'Penélope').first_or_create

    will execute:

        User.where(first_name: 'Penélope').create

    Causing all the `create` callbacks to execute within the context of
    the scope. This could affect queries that occur within callbacks.

        User.find_or_create_by(first_name: 'Penélope')

    will execute:

        User.create(first_name: 'Penélope')

    Which obviously does not affect the scoping of queries within
    callbacks.

    The `find_or_create_by` version also reads better, frankly.

    If you need to add extra attributes during create, you can do one of:

        User.create_with(active: true).find_or_create_by(first_name: 'Jon')
        User.find_or_create_by(first_name: 'Jon') { |u| u.active = true }

    The `first_or_create` family of methods have been nodoc'ed in favour
    of this API. They may be deprecated in the future but their
    implementation is very small and it's probably not worth putting users
    through lots of annoying deprecation warnings.

    *Jon Leighton*

*   Fix bug with presence validation of associations. Would incorrectly add duplicated errors
    when the association was blank. Bug introduced in 1fab518c6a75dac5773654646eb724a59741bc13.

    *Scott Willson*

*   Fix bug where sum(expression) returns string '0' for no matching records.
    Fixes #7439

    *Tim Macfarlane*

*   PostgreSQL adapter correctly fetches default values when using multiple schemas and domains in a db. Fixes #7914

    *Arturo Pie*

*   Learn ActiveRecord::QueryMethods#order work with hash arguments

    When symbol or hash passed we convert it to Arel::Nodes::Ordering.
    If we pass invalid direction(like name: :DeSc) ActiveRecord::QueryMethods#order will raise an exception

        User.order(:name, email: :desc)
        # SELECT "users".* FROM "users" ORDER BY "users"."name" ASC, "users"."email" DESC

    *Tima Maslyuchenko*

*   Rename `ActiveRecord::Fixtures` class to `ActiveRecord::FixtureSet`.
    Instances of this class normally hold a collection of fixtures (records)
    loaded either from a single YAML file, or from a file and a folder
    with the same name.  This change make the class name singular and makes
    the class easier to distinguish from the modules like
    `ActiveRecord::TestFixtures`, which operates on multiple fixture sets,
    or `DelegatingFixtures`, `::Fixtures`, etc.,
    and from the class `ActiveRecord::Fixture`, which corresponds to a single
    fixture.

    *Alexey Muranov*

*   The postgres adapter now supports tables with capital letters.
    Fix #5920

    *Yves Senn*

*   `CollectionAssociation#count` returns `0` without querying if the
    parent record is not persisted.

    Before:

        person.pets.count
        # SELECT COUNT(*) FROM "pets" WHERE "pets"."person_id" IS NULL
        # => 0

    After:

        person.pets.count
        # fires without sql query
        # => 0

    *Francesco Rodriguez*

*   Fix `reset_counters` crashing on `has_many :through` associations.
    Fix #7822.

    *lulalala*

*   Support for partial inserts.

    When inserting new records, only the fields which have been changed
    from the defaults will actually be included in the INSERT statement.
    The other fields will be populated by the database.

    This is more efficient, and also means that it will be safe to
    remove database columns without getting subsequent errors in running
    app processes (so long as the code in those processes doesn't
    contain any references to the removed column).

    The `partial_updates` configuration option is now renamed to
    `partial_writes` to reflect the fact that it now impacts both inserts
    and updates.

    *Jon Leighton*

*   Allow before and after validations to take an array of lifecycle events

    *John Foley*

*   Support for specifying transaction isolation level

    If your database supports setting the isolation level for a transaction, you can set
    it like so:

        Post.transaction(isolation: :serializable) do
          # ...
        end

    Valid isolation levels are:

    * `:read_uncommitted`
    * `:read_committed`
    * `:repeatable_read`
    * `:serializable`

    You should consult the documentation for your database to understand the
    semantics of these different levels:

    * http://www.postgresql.org/docs/9.1/static/transaction-iso.html
    * https://dev.mysql.com/doc/refman/5.0/en/set-transaction.html

    An `ActiveRecord::TransactionIsolationError` will be raised if:

    * The adapter does not support setting the isolation level
    * You are joining an existing open transaction
    * You are creating a nested (savepoint) transaction

    The mysql, mysql2 and postgresql adapters support setting the transaction
    isolation level. However, support is disabled for mysql versions below 5,
    because they are affected by a bug (http://bugs.mysql.com/bug.php?id=39170)
    which means the isolation level gets persisted outside the transaction.

    *Jon Leighton*

*   `ActiveModel::ForbiddenAttributesProtection` is included by default
    in Active Record models. Check the docs of `ActiveModel::ForbiddenAttributesProtection`
    for more details.

    *Guillermo Iguaran*

*   Remove integration between Active Record and
    `ActiveModel::MassAssignmentSecurity`, `protected_attributes` gem
    should be added to use `attr_accessible`/`attr_protected`. Mass
    assignment options has been removed from all the AR methods that
    used it (ex. `AR::Base.new`, `AR::Base.create`, `AR::Base#update_attributes`, etc).

    *Guillermo Iguaran*

*   Fix the return of querying with an empty hash.
    Fix #6971.

        User.where(token: {})

    Before:

        #=> SELECT * FROM users;

    After:

        #=> SELECT * FROM users WHERE 1 = 2;

    *Damien Mathieu*

*   Fix creation of through association models when using `collection=[]`
    on a `has_many :through` association from an unsaved model.
    Fix #7661.

    *Ernie Miller*

*   Explain only normal CRUD sql (select / update / insert / delete).
    Fix problem that explains unexplainable sql.
    Closes #7544 #6458.

    *kennyj*

*   You can now override the generated accessor methods for stored attributes
    and reuse the original behavior with `read_store_attribute` and `write_store_attribute`,
    which are counterparts to `read_attribute` and `write_attribute`.

    *Matt Jones*

*   Accept belongs_to (including polymorphic) association keys in queries.

    The following queries are now equivalent:

        Post.where(author: author)
        Post.where(author_id: author)

        PriceEstimate.where(estimate_of: treasure)
        PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: treasure)

    *Peter Brown*

*   Use native `mysqldump` command instead of `structure_dump` method
    when dumping the database structure to a sql file. Fixes #5547.

    *kennyj*

*   PostgreSQL inet and cidr types are converted to `IPAddr` objects.

    *Dan McClain*

*   PostgreSQL array type support. Any datatype can be used to create an
    array column, with full migration and schema dumper support.

    To declare an array column, use the following syntax:

        create_table :table_with_arrays do |t|
          t.integer :int_array, array: true
          # integer[]
          t.integer :int_array, array: true, length: 2
          # smallint[]
          t.string :string_array, array: true, length: 30
          # char varying(30)[]
        end

    This respects any other migration detail (limits, defaults, etc).
    Active Record will serialize and deserialize the array columns on
    their way to and from the database.

    One thing to note: PostgreSQL does not enforce any limits on the
    number of elements, and any array can be multi-dimensional. Any
    array that is multi-dimensional must be rectangular (each sub array
    must have the same number of elements as its siblings).

    If the `pg_array_parser` gem is available, it will be used when
    parsing PostgreSQL's array representation.

    *Dan McClain*

*   Attribute predicate methods, such as `article.title?`, will now raise
    `ActiveModel::MissingAttributeError` if the attribute being queried for
    truthiness was not read from the database, instead of just returning `false`.

    *Ernie Miller*

*   `ActiveRecord::SchemaDumper` uses Ruby 1.9 style hash, which means that the
    schema.rb file will be generated using this new syntax from now on.

    *Konstantin Shabanov*

*   Map interval with precision to string datatype in PostgreSQL. Fixes #7518.

    *Yves Senn*

*   Fix eagerly loading associations without primary keys. Fixes #4976.

    *Kelley Reynolds*

*   Rails now raise an exception when you're trying to run a migration that has an invalid
    file name. Only lower case letters, numbers, and '_' are allowed in migration's file name.
    Please see #7419 for more details.

    *Jan Bernacki*

*   Fix bug when calling `store_accessor` multiple times.
    Fixes #7532.

    *Matt Jones*

*   Fix store attributes that show the changes incorrectly.
    Fixes #7532.

    *Matt Jones*

*   Fix `ActiveRecord::Relation#pluck` when columns or tables are reserved words.

    *Ian Lesperance*

*   Allow JSON columns to be created in PostgreSQL and properly encoded/decoded.
    to/from database.

    *Dickson S. Guedes*

*   Fix time column type casting for invalid time string values to correctly return `nil`.

    *Adam Meehan*

*   Allow to pass Symbol or Proc into `:limit` option of #accepts_nested_attributes_for.

    *Mikhail Dieterle*

*   ActiveRecord::SessionStore has been extracted from Active Record as `activerecord-session_store`
    gem. Please read the `README.md` file on the gem for the usage.

    *Prem Sichanugrist*

*   Fix `reset_counters` when there are multiple `belongs_to` association with the
    same foreign key and one of them have a counter cache.
    Fixes #5200.

    *Dave Desrochers*

*   `serialized_attributes` and `_attr_readonly` become class method only. Instance reader methods are deprecated.

    *kennyj*

*   Round usec when comparing timestamp attributes in the dirty tracking.
    Fixes #6975.

    *kennyj*

*   Use inversed parent for first and last child of `has_many` association.

    *Ravil Bayramgalin*

*   Fix `Column.microseconds` and `Column.fast_string_to_time` to avoid converting
    timestamp seconds to a float, since it occasionally results in inaccuracies
    with microsecond-precision times. Fixes #7352.

    *Ari Pollak*

*   Fix AR#dup to nullify the validation errors in the dup'ed object. Previously the original
    and the dup'ed object shared the same errors.

    *Christian Seiler*

*   Raise `ArgumentError` if list of attributes to change is empty in `update_all`.

    *Roman Shatsov*

*   Fix AR#create to return an unsaved record when AR::RecordInvalid is
    raised. Fixes #3217.

    *Dave Yeu*

*   Fixed table name prefix that is generated in engines for namespaced models.

    *Wojciech Wnętrzak*

*   Make sure `:environment` task is executed before `db:schema:load` or `db:structure:load`.
    Fixes #4772.

    *Seamus Abshere*

*   Allow Relation#merge to take a proc.

    This was requested by DHH to allow creating of one's own custom
    association macros.

    For example:

        module Commentable
          def has_many_comments(extra)
            has_many :comments, -> { where(:foo).merge(extra) }
          end
        end

        class Post < ActiveRecord::Base
          extend Commentable
          has_many_comments -> { where(:bar) }
        end

    *Jon Leighton*

*   Add CollectionProxy#scope.

    This can be used to get a Relation from an association.

    Previously we had a #scoped method, but we're deprecating that for
    AR::Base, so it doesn't make sense to have it here.

    This was requested by DHH, to facilitate code like this:

        Project.scope.order('created_at DESC').page(current_page).tagged_with(@tag).limit(5).scoping do
          @topics      = @project.topics.scope
          @todolists   = @project.todolists.scope
          @attachments = @project.attachments.scope
          @documents   = @project.documents.scope
        end

    *Jon Leighton*

*   Add `Relation#load`.

    This method explicitly loads the records and then returns `self`.

    Rather than deciding between "do I want an array or a relation?",
    most people are actually asking themselves "do I want to eager load
    or lazy load?" Therefore, this method provides a way to explicitly
    eager-load without having to switch from a `Relation` to an array.

    Example:

        @posts = Post.where(published: true).load

    *Jon Leighton*

*   `Relation#order`: make new order prepend old one.

        User.order("name asc").order("created_at desc")
        # SELECT * FROM users ORDER BY created_at desc, name asc

    This also affects order defined in `default_scope` or any kind of associations.

    *Bogdan Gusiev*

*   `Model.all` now returns an `ActiveRecord::Relation`, rather than an
    array of records. Use `Relation#to_a` if you really want an array.

    In some specific cases, this may cause breakage when upgrading.
    However in most cases the `ActiveRecord::Relation` will just act as a
    lazy-loaded array and there will be no problems.

    Note that calling `Model.all` with options (e.g.
    `Model.all(conditions: '...')` was already deprecated, but it will
    still return an array in order to make the transition easier.

    `Model.scoped` is deprecated in favour of `Model.all`.

    `Relation#all` still returns an array, but is deprecated (since it
    would serve no purpose if we made it return a `Relation`).

    *Jon Leighton*

*   `:finder_sql` and `:counter_sql` options on collection associations
    are deprecated. Please transition to using scopes.

    *Jon Leighton*

*   `:insert_sql` and `:delete_sql` options on `has_and_belongs_to_many`
    associations are deprecated. Please transition to using `has_many
    :through`.

    *Jon Leighton*

*   Added `#update_columns` method which updates the attributes from
    the passed-in hash without calling save, hence skipping validations and
    callbacks. `ActiveRecordError` will be raised when called on new objects
    or when at least one of the attributes is marked as read only.

        post.attributes # => {"id"=>2, "title"=>"My title", "body"=>"My content", "author"=>"Peter"}
        post.update_columns(title: 'New title', author: 'Sebastian') # => true
        post.attributes # => {"id"=>2, "title"=>"New title", "body"=>"My content", "author"=>"Sebastian"}

    *Sebastian Martinez + Rafael Mendonça França*

*   The migration generator now creates a join table with (commented) indexes every time
    the migration name contains the word `join_table`:

        rails g migration create_join_table_for_artists_and_musics artist_id:index music_id

    *Aleksey Magusev*

*   Add `add_reference` and `remove_reference` schema statements. Aliases, `add_belongs_to`
    and `remove_belongs_to` are acceptable. References are reversible.

    Examples:

        # Create a user_id column
        add_reference(:products, :user)
        # Create a supplier_id, supplier_type columns and appropriate index
        add_reference(:products, :supplier, polymorphic: true, index: true)
        # Remove polymorphic reference
        remove_reference(:products, :supplier, polymorphic: true)

    *Aleksey Magusev*

*   Add `:default` and `:null` options to `column_exists?`.

        column_exists?(:testings, :taggable_id, :integer, null: false)
        column_exists?(:testings, :taggable_type, :string, default: 'Photo')

    *Aleksey Magusev*

*   `ActiveRecord::Relation#inspect` now makes it clear that you are
    dealing with a `Relation` object rather than an array:.

        User.where(age: 30).inspect
        # => <ActiveRecord::Relation [#<User ...>, #<User ...>, ...]>

        User.where(age: 30).to_a.inspect
        # => [#<User ...>, #<User ...>]

    The number of records displayed will be limited to 10.

    *Brian Cardarella, Jon Leighton & Damien Mathieu*

*   Add `collation` and `ctype` support to PostgreSQL. These are available for PostgreSQL 8.4 or later.
    Example:

        development:
          adapter: postgresql
          host: localhost
          database: rails_development
          username: foo
          password: bar
          encoding: UTF8
          collation: ja_JP.UTF8
          ctype: ja_JP.UTF8

    *kennyj*

*   Changed validates_presence_of on an association so that children objects
    do not validate as being present if they are marked for destruction. This
    prevents you from saving the parent successfully and thus putting the parent
    in an invalid state.

    *Nick Monje & Brent Wheeldon*

*   `FinderMethods#exists?` now returns `false` with the `false` argument.

    *Egor Lynko*

*   Added support for specifying the precision of a timestamp in the postgresql
    adapter. So, instead of having to incorrectly specify the precision using the
    `:limit` option, you may use `:precision`, as intended. For example, in a migration:

        def change
          create_table :foobars do |t|
            t.timestamps :precision => 0
          end
        end

    *Tony Schneider*

*   Allow `ActiveRecord::Relation#pluck` to accept multiple columns. Returns an
    array of arrays containing the typecasted values:

        Person.pluck(:id, :name)
        # SELECT people.id, people.name FROM people
        # [[1, 'David'], [2, 'Jeremy'], [3, 'Jose']]

    *Jeroen van Ingen & Carlos Antonio da Silva*

*   Improve the derivation of HABTM join table name to take account of nesting.
    It now takes the table names of the two models, sorts them lexically and
    then joins them, stripping any common prefix from the second table name.

    Some examples:

        Top level models (Category <=> Product)
        Old: categories_products
        New: categories_products

        Top level models with a global table_name_prefix (Category <=> Product)
        Old: site_categories_products
        New: site_categories_products

        Nested models in a module without a table_name_prefix method (Admin::Category <=> Admin::Product)
        Old: categories_products
        New: categories_products

        Nested models in a module with a table_name_prefix method (Admin::Category <=> Admin::Product)
        Old: categories_products
        New: admin_categories_products

        Nested models in a parent model (Catalog::Category <=> Catalog::Product)
        Old: categories_products
        New: catalog_categories_products

        Nested models in different parent models (Catalog::Category <=> Content::Page)
        Old: categories_pages
        New: catalog_categories_content_pages

    *Andrew White*

*   Move HABTM validity checks to `ActiveRecord::Reflection`. One side effect of
    this is to move when the exceptions are raised from the point of declaration
    to when the association is built. This is consistant with other association
    validity checks.

    *Andrew White*

*   Added `stored_attributes` hash which contains the attributes stored using
    `ActiveRecord::Store`. This allows you to retrieve the list of attributes
    you've defined.

       class User < ActiveRecord::Base
         store :settings, accessors: [:color, :homepage]
       end

       User.stored_attributes[:settings] # [:color, :homepage]

    *Joost Baaij & Carlos Antonio da Silva*

*   PostgreSQL default log level is now 'warning', to bypass the noisy notice
    messages. You can change the log level using the `min_messages` option
    available in your config/database.yml.

    *kennyj*

*   Add uuid datatype support to PostgreSQL adapter.

    *Konstantin Shabanov*

*   Added `ActiveRecord::Migration.check_pending!` that raises an error if
    migrations are pending.

    *Richard Schneeman*

*   Added `#destroy!` which acts like `#destroy` but will raise an
    `ActiveRecord::RecordNotDestroyed` exception instead of returning `false`.

    *Marc-André Lafortune*

*   Added support to `CollectionAssociation#delete` for passing `fixnum`
    or `string` values as record ids. This finds the records responding
    to the `id` and executes delete on them.

        class Person < ActiveRecord::Base
          has_many :pets
        end

        person.pets.delete("1") # => [#<Pet id: 1>]
        person.pets.delete(2, 3) # => [#<Pet id: 2>, #<Pet id: 3>]

    *Francesco Rodriguez*

*   Deprecated most of the 'dynamic finder' methods. All dynamic methods
    except for `find_by_...` and `find_by_...!` are deprecated. Here's
    how you can rewrite the code:

      * `find_all_by_...` can be rewritten using `where(...)`
      * `find_last_by_...` can be rewritten using `where(...).last`
      * `scoped_by_...` can be rewritten using `where(...)`
      * `find_or_initialize_by_...` can be rewritten using
        `where(...).first_or_initialize`
      * `find_or_create_by_...` can be rewritten using
        `find_or_create_by(...)` or where(...).first_or_create`
      * `find_or_create_by_...!` can be rewritten using
        `find_or_create_by!(...) or `where(...).first_or_create!`

    The implementation of the deprecated dynamic finders has been moved
    to the `activerecord-deprecated_finders` gem. See below for details.

    *Jon Leighton*

*   Deprecated the old-style hash based finder API. This means that
    methods which previously accepted "finder options" no longer do. For
    example this:

        Post.find(:all, conditions: { comments_count: 10 }, limit: 5)

    Should be rewritten in the new style which has existed since Rails 3:

        Post.where(comments_count: 10).limit(5)

    Note that as an interim step, it is possible to rewrite the above as:

        Post.all.merge(where: { comments_count: 10 }, limit: 5)

    This could save you a lot of work if there is a lot of old-style
    finder usage in your application.

    `Relation#merge` now accepts a hash of
    options, but they must be identical to the names of the equivalent
    finder method. These are mostly identical to the old-style finder
    option names, except in the following cases:

      * `:conditions` becomes `:where`.
      * `:include` becomes `:includes`.
      * `:extend` becomes `:extending`.

    The code to implement the deprecated features has been moved out to
    the `activerecord-deprecated_finders` gem. This gem is a dependency
    of Active Record in Rails 4.0. It will no longer be a dependency
    from Rails 4.1, but if your app relies on the deprecated features
    then you can add it to your own Gemfile. It will be maintained by
    the Rails core team until Rails 5.0 is released.

    *Jon Leighton*

*   It's not possible anymore to destroy a model marked as read only.

    *Johannes Barre*

*   Added ability to ActiveRecord::Relation#from to accept other ActiveRecord::Relation objects.

      Record.from(subquery)
      Record.from(subquery, :a)

    *Radoslav Stankov*

*   Added custom coders support for ActiveRecord::Store. Now you can set
    your custom coder like this:

        store :settings, accessors: [ :color, :homepage ], coder: JSON

    *Andrey Voronkov*

*   `mysql` and `mysql2` connections will set `SQL_MODE=STRICT_ALL_TABLES` by
    default to avoid silent data loss. This can be disabled by specifying
    `strict: false` in your `database.yml`.

    *Michael Pearson*

*   Added default order to `first` to assure consistent results among
    different database engines. Introduced `take` as a replacement to
    the old behavior of `first`.

    *Marcelo Silveira*

*   Added an `:index` option to automatically create indexes for references
    and belongs_to statements in migrations.

    The `references` and `belongs_to` methods now support an `index`
    option that receives either a boolean value or an options hash
    that is identical to options available to the add_index method:

      create_table :messages do |t|
        t.references :person, index: true
      end

      Is the same as:

      create_table :messages do |t|
        t.references :person
      end
      add_index :messages, :person_id

    Generators have also been updated to use the new syntax.

    *Joshua Wood*

*   Added bang methods for mutating `ActiveRecord::Relation` objects.
    For example, while `foo.where(:bar)` will return a new object
    leaving `foo` unchanged, `foo.where!(:bar)` will mutate the foo
    object

    *Jon Leighton*

*   Added `#find_by` and `#find_by!` to mirror the functionality
    provided by dynamic finders in a way that allows dynamic input more
    easily:

        Post.find_by name: 'Spartacus', rating: 4
        Post.find_by "published_at < ?", 2.weeks.ago
        Post.find_by! name: 'Spartacus'

    *Jon Leighton*

*   Added ActiveRecord::Base#slice to return a hash of the given methods with
    their names as keys and returned values as values.

    *Guillermo Iguaran*

*   Deprecate eager-evaluated scopes.

    Don't use this:

        scope :red, where(color: 'red')
        default_scope where(color: 'red')

    Use this:

        scope :red, -> { where(color: 'red') }
        default_scope { where(color: 'red') }

    The former has numerous issues. It is a common newbie gotcha to do
    the following:

        scope :recent, where(published_at: Time.now - 2.weeks)

    Or a more subtle variant:

        scope :recent, -> { where(published_at: Time.now - 2.weeks) }
        scope :recent_red, recent.where(color: 'red')

    Eager scopes are also very complex to implement within Active
    Record, and there are still bugs. For example, the following does
    not do what you expect:

        scope :remove_conditions, except(:where)
        where(...).remove_conditions # => still has conditions

    *Jon Leighton*

*   Remove IdentityMap

    IdentityMap has never graduated to be an "enabled-by-default" feature, due
    to some inconsistencies with associations, as described in this commit:

       https://github.com/rails/rails/commit/302c912bf6bcd0fa200d964ec2dc4a44abe328a6

    Hence the removal from the codebase, until such issues are fixed.

    *Carlos Antonio da Silva*

*   Added the schema cache dump feature.

    `Schema cache dump` feature was implemetend. This feature can dump/load internal state of `SchemaCache` instance
    because we want to boot rails more quickly when we have many models.

    Usage notes:

      1) execute rake task.
      RAILS_ENV=production bundle exec rake db:schema:cache:dump
      => generate db/schema_cache.dump

      2) add config.active_record.use_schema_cache_dump = true in config/production.rb. BTW, true is default.

      3) boot rails.
      RAILS_ENV=production bundle exec rails server
      => use db/schema_cache.dump

      4) If you remove clear dumped cache, execute rake task.
      RAILS_ENV=production bundle exec rake db:schema:cache:clear
      => remove db/schema_cache.dump

    *kennyj*

*   Added support for partial indices to PostgreSQL adapter.

    The `add_index` method now supports a `where` option that receives a
    string with the partial index criteria.

        add_index(:accounts, :code, where: 'active')

        Generates

        CREATE INDEX index_accounts_on_code ON accounts(code) WHERE active

    *Marcelo Silveira*

*   Implemented ActiveRecord::Relation#none method.

    The `none` method returns a chainable relation with zero records
    (an instance of the NullRelation class).

    Any subsequent condition chained to the returned relation will continue
    generating an empty relation and will not fire any query to the database.

    *Juanjo Bazán*

*   Added the `ActiveRecord::NullRelation` class implementing the null
    object pattern for the Relation class.

    *Juanjo Bazán*

*   Added new `dependent: :restrict_with_error` option. This will add
    an error to the model, rather than raising an exception.

    The `:restrict` option is renamed to `:restrict_with_exception` to
    make this distinction explicit.

    *Manoj Kumar & Jon Leighton*

*   Added `create_join_table` migration helper to create HABTM join tables.

        create_join_table :products, :categories
        # =>
        # create_table :categories_products, id: false do |td|
        #   td.integer :product_id,  null: false
        #   td.integer :category_id, null: false
        # end

    *Rafael Mendonça França*

*   The primary key is always initialized in the @attributes hash to `nil` (unless
    another value has been specified).

    *Aaron Paterson*

*   In previous releases, the following would generate a single query with
    an `OUTER JOIN comments`, rather than two separate queries:

        Post.includes(:comments)
            .where("comments.name = 'foo'")

    This behaviour relies on matching SQL string, which is an inherently
    flawed idea unless we write an SQL parser, which we do not wish to
    do.

    Therefore, it is now deprecated.

    To avoid deprecation warnings and for future compatibility, you must
    explicitly state which tables you reference, when using SQL snippets:

        Post.includes(:comments)
            .where("comments.name = 'foo'")
            .references(:comments)

    Note that you do not need to explicitly specify references in the
    following cases, as they can be automatically inferred:

        Post.where(comments: { name: 'foo' })
        Post.where('comments.name' => 'foo')
        Post.order('comments.name')

    You also do not need to worry about this unless you are doing eager
    loading. Basically, don't worry unless you see a deprecation warning
    or (in future releases) an SQL error due to a missing JOIN.

    *Jon Leighton*

*   Support for the `schema_info` table has been dropped. Please
    switch to `schema_migrations`.

    *Aaron Patterson*

*   Connections *must* be closed at the end of a thread. If not, your
    connection pool can fill and an exception will be raised.

    *Aaron Patterson*

*   PostgreSQL hstore records can be created.

    *Aaron Patterson*

*   PostgreSQL hstore types are automatically deserialized from the database.

    *Aaron Patterson*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/activerecord/CHANGELOG.md) for previous changes.
