## Rails 4.0.0.rc2 (June 11, 2013) ##

*   Fix `add_column` with `array` option when using PostgreSQL. Fixes #10432

*   Do not overwrite manually built records during one-to-one nested attribute assignment

    For one-to-one nested associations, if you build the new (in-memory)
    child object yourself before assignment, then the NestedAttributes
    module will not overwrite it, e.g.:

        class Member < ActiveRecord::Base
          has_one :avatar
          accepts_nested_attributes_for :avatar

          def avatar
            super || build_avatar(width: 200)
          end
        end

        member = Member.new
        member.avatar_attributes = {icon: 'sad'}
        member.avatar.width # => 200

    *Olek Janiszewski*

*   fixes bug introduced by #3329.  Now, when autosaving associations,
    deletions happen before inserts and saves.  This prevents a 'duplicate
    unique value' database error that would occur if a record being created had
    the same value on a unique indexed field as that of a record being destroyed.

    *Adam Anderson*


*   Fix pending migrations error when loading schema and `ActiveRecord::Base.table_name_prefix`
    is not blank.

    Call `assume_migrated_upto_version` on connection to prevent it from first
    being picked up in `method_missing`.

    In the base class, `Migration`, `method_missing` expects the argument to be a
    table name, and calls `proper_table_name` on the arguments before sending to
    `connection`. If `table_name_prefix` or `table_name_suffix` is used, the schema
    version changes to `prefix_version_suffix`, breaking `rake test:prepare`.

    Fixes #10411.

    *Kyle Stevens*

*   Mute `psql` output when running rake db:schema:load.

    *Godfrey Chan*


## Rails 4.0.0.rc1 (April 29, 2013) ##

*   Trigger a save on `has_one association=(associate)` when the associate contents have changed.

    Fix #8856.

    *Chris Thompson*

*   Allow to use databases.rake tasks without having `Rails.application`.

    *Piotr Sarnacki*

*   Fix a `SystemStackError` problem when using time zone aware or serialized attributes.
    In current implementation, we reuse `column_types` argument when initiating an instance.
    If an instance has serialized or time zone aware attributes, `column_types` is
    wrapped multiple times in `decorate_columns` method. Thus the above error occurs.

    *Dan Erikson & kennyj*

*   Fix for a regression bug in which counter cache columns were not being updated
    when record was pushed into a has_many association. For example:

        Post.first.comments << Comment.create

    Fixes #3891.

    *Matthew Robertson*

*   If a model was instantiated from the database using `select`, `respond_to?`
    returns false for non-selected attributes. For example:

        post = Post.select(:title).first
        post.respond_to?(:body) # => false

        post = Post.select('title as post_title').first
        post.respond_to?(:title) # => false

    Fixes #4208.

    *Neeraj Singh*

*   Run `rake migrate:down` & `rake migrate:up` in transaction if database supports.

    *Alexander Bondarev*

*   `0x` prefix must be added when assigning hexadecimal string into `bit` column in PostgreSQL.

    *kennyj*

*   Added Statement Cache to allow the caching of a single statement. The cache works by
    duping the relation returned from yielding a statement, which allows skipping the AST
    building phase for following executes. The cache returns results in array format.

    Example:

        cache = ActiveRecord::StatementCache.new do
          Book.where(name: "my book").limit(100)
        end

        books = cache.execute

    The solution attempts to get closer to the speed of `find_by_sql` but still maintaining
    the expressiveness of the Active Record queries.

    *Olli Rissanen*

*   Preserve context while merging relations with join information.

        class Comment < ActiveRecord::Base
          belongs_to :post
        end

        class Author < ActiveRecord::Base
          has_many :posts
        end

        class Post < ActiveRecord::Base
          belongs_to :author
          has_many :comments
        end

    `Comment.joins(:post).merge(Post.joins(:author).merge(Author.where(:name => "Joe Blogs"))).all`
    would fail with
    `ActiveRecord::ConfigurationError: Association named 'author' was not found on Comment`.

    It is failing because `all` is being called on relation which looks like this after all
    the merging: `{:joins=>[:post, :author], :where=>[#<Arel::Nodes::Equality: ....}`. In this
    relation all the context that `Post` was joined with `Author` is lost and hence the error
    that `author` was not found on `Comment`.

    The solution is to build `JoinAssociation` when two relations with join information are being
    merged. And later while building the Arel use the previously built `JoinAssociation` record
    in `JoinDependency#graft` to build the right from clause.
    Fixes #3002.

    *Jared Armstrong and Neeraj Singh*

*   `default_scopes?` is deprecated. Check for `default_scopes.empty?` instead.

    *Agis Anastasopoulos*

*   Default values for PostgreSQL bigint types now get parsed and dumped to the
    schema correctly.

    *Erik Peterson*

*   Fix associations with `:inverse_of` option when building association
    with a block. Inside the block the parent object was different then
    after the block.

    Example:

        parent.association.build do |child|
          child.parent.equal?(parent) # false
        end

        # vs

        child = parent.association.build
        child.parent.equal?(parent) # true

    *Michal Cichra*

*   `has_many` using `:through` now obeys the order clause mentioned in
    through association.
    Fixes #10016.

    *Neeraj Singh*

*   `belongs_to :touch` behavior now touches old association when
    transitioning to new association.

        class Passenger < ActiveRecord::Base
          belongs_to :car, touch: true
        end

        car_1 = Car.create
        car_2 = Car.create

        passenger = Passenger.create car: car_1

        passenger.car = car_2
        passenger.save

    Previously only car_2 would be touched. Now both car_1 and car_2
    will be touched.

    *Adam Gamble*

*   Extract and deprecate Firebird / Sqlserver / Oracle database tasks, because
    These tasks should be supported by 3rd-party adapter.

    *kennyj*

*   Allow `ActiveRecord::Base.connection_handler` to have thread affinity and be
    settable, this effectively allows Active Record to be used in a multithreaded
    setup with multiple connections to multiple databases.

    *Sam Saffron*

*   `rename_column` preserves `auto_increment` in MySQL migrations.
    Fixes #3493.

    *Vipul A M*

*   PostgreSQL geometric type point is now supported by Active Record. Fixes #7324.

    *Martin Schuerrer*

*   Add support for concurrent indexing in PostgreSQL adapter via the
    `algorithm: :concurrently` option.

        add_index(:people, :last_name, algorithm: :concurrently)

    Also add support for MySQL index algorithms (`COPY`, `INPLACE`,
    `DEFAULT`) via the `:algorithm` option.

        add_index(:people, :last_name, algorithm: :copy) # or :inplace/:default

    *Dan McClain*

*   Add support for fulltext and spatial indexes on MySQL tables with MyISAM database
    engine via the `type: 'FULLTEXT'` / `type: 'SPATIAL'` option.

        add_index(:people, :last_name, type: 'FULLTEXT')
        add_index(:people, :last_name, type: 'SPATIAL')

    *Ken Mazaika*

*   Add an `add_index` override in PostgreSQL adapter and MySQL adapter
    to allow custom index type support.
    Fixes #6101.

        add_index(:wikis, :body, :using => 'gin')

    *Stefan Huber* and *Doabit*

*   After extraction of mass-assignment attributes (which protects [id, type]
    by default) we can pass id to `update_attributes` and it will update
    another record because id will be used in where statement. We never have
    to change id in where statement because we try to set/replace fields for
    already loaded record but we have to try to set new id for that record.

    *Dmitry Vorotilin*

*   Models with multiple counter cache associations now update correctly on destroy.
    See #7706.

    *Ian Young*

*   If `:inverse_of` is true on an association, then when one calls `find()` on
    the association, Active Record will first look through the in-memory objects
    in the association for a particular id. Then, it will go to the DB if it
    is not found. This is accomplished by calling `find_by_scan` in
    collection associations whenever `options[:inverse_of]` is not nil.
    Fixes #9470.

    *John Wang*

*   `rake db:create` does not change permissions of the MySQL root user.
    Fixes #8079.

    *Yves Senn*

*   The length of the `version` column in the `schema_migrations` table
    created by the `mysql2` adapter is 191 if the encoding is "utf8mb4".

    The "utf8" encoding in MySQL has support for a maximum of 3 bytes per character,
    and only contains characters from the BMP. The recently added
    [utf8mb4](http://dev.mysql.com/doc/refman/5.5/en/charset-unicode-utf8mb4.html)
    encoding extends the support to four bytes. As of this writing, said encoding
    is supported in the betas of the `mysql2` gem.

    Setting the encoding to "utf8mb4" has
    [a few implications](http://dev.mysql.com/doc/refman/5.5/en/charset-unicode-upgrading.html).
    This change addresses the max length for indexes, which is 191 instead of 255.

    *Xavier Noria*

*   Counter caches on associations will now stay valid when attributes are
    updated (not just when records are created or destroyed), for example,
    when calling `update_attributes`. The following code now works:

        class Comment < ActiveRecord::Base
          belongs_to :post, counter_cache: true
        end

        class Post < ActiveRecord::Base
          has_many :comments
        end

        post = Post.create
        comment = Comment.create

        post.comments << comment
        post.save.reload.comments_count # => 1
        comment.update_attributes(post_id: nil)

        post.save.reload.comments_count # => 0

    Updating the id of a `belongs_to` object with the id of a new object will
    also keep the count accurate.

    *John Wang*

*   Referencing join tables implicitly was deprecated. There is a
    possibility that these deprecation warnings are shown even if you
    don't make use of that feature. You can now disable the feature entirely.
    Fixes #9712.

    Example:

        # in your configuration
        config.active_record.disable_implicit_join_references = true

        # or directly
        ActiveRecord::Base.disable_implicit_join_references = true

    *Yves Senn*

*   The `:distinct` option for `Relation#count` is deprecated. You
    should use `Relation#distinct` instead.

    Example:

        # Before
        Post.select(:author_name).count(distinct: true)

        # After
        Post.select(:author_name).distinct.count

    *Yves Senn*

*   Rename `Relation#uniq` to `Relation#distinct`. `#uniq` is still
    available as an alias but we encourage to use `#distinct` instead.
    Also `Relation#uniq_value` is aliased to `Relation#distinct_value`,
    this is a temporary solution and you should migrate to `distinct_value`.

    *Yves Senn*

*   Fix quoting for sqlite migrations using `copy_table_contents` with binary
    columns.

    These would fail with "SQLite3::SQLException: unrecognized token" because
    the column was not being passed to `quote` so the data was not quoted
    correctly.

    *Matthew M. Boedicker*

*   Promotes `change_column_null` to the migrations API. This macro sets/removes
    `NOT NULL` constraints, and accepts an optional argument to replace existing
    `NULL`s if needed. The adapters for SQLite, MySQL, PostgreSQL, and (at least)
    Oracle, already implement this method.

    *Xavier Noria*

*   Uniqueness validation allows you to pass `:conditions` to limit
    the constraint lookup.

    Example:

        validates_uniqueness_of :title, conditions: -> { where('approved = ?', true) }

    *Mattias Pfeiffer + Yves Senn*

*   `connection` is deprecated as an instance method.
    This allows end-users to have a `connection` method on their models
    without clashing with Active Record internals.

    *Ben Moss*

*   When copying migrations, preserve their magic comments and content encoding.

    *OZAWA Sakuro*

*   Fix `subclass_from_attrs` when `eager_load` is false. It cannot find
    subclass because all classes are loaded automatically when it needs.

    *Dmitry Vorotilin*

*   When `:name` option is provided to `remove_index`, use it if there is no
    index by the conventional name.

    For example, previously if an index was removed like so
    `remove_index :values, column: :value, name: 'a_different_name'`
    the generated SQL would not contain the specified index name,
    and hence the migration would fail.
    Fixes #8858.

    *Ezekiel Smithburg*

*   Created block to by-pass the prepared statement bindings.
    This will allow to compose fragments of large SQL statements to
    avoid multiple round-trips between Ruby and the DB.

    Example:

        sql = Post.connection.unprepared_statement do
          Post.first.comments.to_sql
        end

    *Cédric Fabianski*

*   Change the semantics of combining scopes to be the same as combining
    class methods which return scopes. For example:

        class User < ActiveRecord::Base
          scope :active,   -> { where state: 'active' }
          scope :inactive, -> { where state: 'inactive' }
        end

        class Post < ActiveRecord::Base
          def self.active
            where state: 'active'
          end

          def self.inactive
            where state: 'inactive'
          end
        end

        ### BEFORE ###

        User.where(state: 'active').where(state: 'inactive')
        # => SELECT * FROM users WHERE state = 'active' AND state = 'inactive'

        User.active.inactive
        # => SELECT * FROM users WHERE state = 'inactive'

        Post.active.inactive
        # => SELECT * FROM posts WHERE state = 'active' AND state = 'inactive'

        ### AFTER ###

        User.active.inactive
        # => SELECT * FROM posts WHERE state = 'active' AND state = 'inactive'

    Before this change, invoking a scope would merge it into the current
    scope and return the result. `Relation#merge` applies "last where
    wins" logic to de-duplicate the conditions, but this lead to
    confusing and inconsistent behaviour. This fixes that.

    If you really do want the "last where wins" logic, you can opt-in to
    it like so:

        User.active.merge(User.inactive)

    Fixes #7365.

    *Neeraj Singh* and *Jon Leighton*

*   Expand `#cache_key` to consult all relevant updated timestamps.

    Previously only `updated_at` column was checked, now it will
    consult other columns that received updated timestamps on save,
    such as `updated_on`.  When multiple columns are present it will
    use the most recent timestamp.
    Fixes #9033.

    *Brendon Murphy*

*   Throw `NotImplementedError` when trying to instantiate `ActiveRecord::Base` or an abstract class.

    *Aaron Weiner*

*   Warn when `rake db:structure:dump` with a MySQL database and
    `mysqldump` is not in the PATH or fails.
    Fixes #9518.

    *Yves Senn*

*   Remove `connection#structure_dump`, which is no longer used. *Yves Senn*

*   Make it possible to execute migrations without a transaction even
    if the database adapter supports DDL transactions.
    Fixes #9483.

    Example:

        class ChangeEnum < ActiveRecord::Migration
          disable_ddl_transaction!

          def up
            execute "ALTER TYPE model_size ADD VALUE 'new_value'"
          end
        end

    *Yves Senn*

*   Assigning "0.0" to a nullable numeric column does not make it dirty.
    Fixes #9034.

    Example:

        product = Product.create price: 0.0
        product.price = '0.0'
        product.changed? # => false (this used to return true)
        product.changes # => {} (this used to return { price: [0.0, 0.0] })

    *Yves Senn*

*   Added functionality to unscope relations in a relations chain. For
    instance, if you are passed in a chain of relations as follows:

        User.where(name: "John").order('id DESC')

    but you want to get rid of order, then this feature allows you to do:

        User.where(name: "John").order('id DESC').unscope(:order)
            == User.where(name: "John")

    The .unscope() function is more general than the .except() method because
    .except() only works on the relation it is acting on. However, .unscope()
    works for any relation in the entire relation chain.

    *John Wang*

*   PostgreSQL timestamp with time zone (timestamptz) datatype now returns a
    ActiveSupport::TimeWithZone instance instead of a string

    *Troy Kruthoff*

*   The `#append` method for collection associations behaves like`<<`.
    `#prepend` is not defined and `<<` or `#append` should be used.
    Fixes #7364.

    *Yves Senn*

*   Added support for creating a table via Rails migration generator.
    For example,

        rails g migration create_books title:string content:text

    will generate a migration that creates a table called books with
    the listed attributes, without creating a model.

    *Sammy Larbi*

*   Fix bug that raises the wrong exception when the exception handled by PostgreSQL adapter
    doesn't respond to `#result`.
    Fixes #8617.

    *kennyj*

*   Support PostgreSQL specific column types when using `change_table`.
    Fixes #9480.

    Example:

        change_table :authors do |t|
          t.hstore :books
          t.json :metadata
        end

    *Yves Senn*

*   Revert 408227d9c5ed7d, 'quote numeric'. This introduced some regressions.

    *Steve Klabnik*

*   Fix calculation of `db_runtime` property in
   `ActiveRecord::Railties::ControllerRuntime#cleanup_view_runtime`.
    Previously, after raising `ActionView::MissingTemplate`, `db_runtime` was
    not populated.
    Fixes #9215.

    *Igor Fedoronchuk*

*   Do not try to touch invalid (and thus not persisted) parent record
    for a `belongs_to :parent, touch: true` association

    *Olek Janiszewski*

*   Fix when performing an ordered join query. The bug only
    affected queries where the order was given with a symbol.
    Fixes #9275.

    Example:

        # This will expand the order :name to "authors".name.
        Author.joins(:books).where('books.published = 1').order(:name)


## Rails 4.0.0.beta1 (February 25, 2013) ##

*   Fix overriding of attributes by `default_scope` on `ActiveRecord::Base#dup`.

    *Hiroshige UMINO*

*   Update queries now use prepared statements.

    *Olli Rissanen*

*   Fixing issue #8345. Now throwing an error when one attempts to touch a
    new object that has not yet been persisted. For instance:

    Example:

        ball = Ball.new
        ball.touch :updated_at   # => raises error

    It is not until the ball object has been persisted that it can be touched.
    This follows the behavior of update_column.

    *John Wang*

*   Preloading ordered `has_many :through` associations no longer applies
    invalid ordering to the `:through` association.
    Fixes #8663.

    *Yves Senn*

*   The auto explain feature has been removed. This feature was
    activated by configuring `config.active_record.auto_explain_threshold_in_seconds`.
    The configuration option was deprecated and has no more effect.

    You can still use `ActiveRecord::Relation#explain` to see the EXPLAIN output for
    any given relation.

    *Yves Senn*

*   The `:on` option for `after_commit` and `after_rollback` now
    accepts an Array of actions.
    Fixes #988.

    Example:

        after_commit :update_cache on: [:create, :update]

    *Yves Senn*

*   Rename related indexes on `rename_table` and `rename_column`. This
    does not affect indexes with custom names.

    *Yves Senn*

*   Prevent the creation of indices with too long names, which cause
    internal operations to fail (sqlite3 adapter only). The method
    `allowed_index_name_length` defines the length limit enforced by
    rails. It's value defaults to `index_name_length` but can vary per adapter.
    Fixes #8264.

    *Yves Senn*

*   Fixing issue #776.

    Memory bloat in transactions is handled by having the transaction hold only
    the AR objects which it absolutely needs to know about. These are the AR
    objects with callbacks (they need to be updated as soon as something in the
    transaction occurs).

    All other AR objects can be updated lazily by keeping a reference to a
    TransactionState object. If an AR object gets inside a transaction, then
    the transaction will add its TransactionState to the AR object. When the
    user makes a call to some attribute on an AR object (which has no
    callbacks) associated with a transaction, the AR object will call the
    sync_with_transaction_state method and make sure it is up to date with the
    transaction. After it has synced with the transaction state, the AR object
    will return the attribute that was requested.

    Most of the logic in the changes are used to handle multiple transactions,
    in which case the AR object has to recursively follow parent pointers of
    TransactionState objects.

    *John Wang*

*   Descriptive error message when the necessary AR adapter gem was not found.
    Fixes #7313.

    *Yves Senn*

*   Active Record now raises an error when blank arguments are passed to query
    methods for which blank arguments do not make sense.

    Example:

        Post.includes()     # => raises error

    *John Wang*

*   Simplified type casting code for timezone aware attributes to use the
    `in_time_zone` method if it is available. This introduces a subtle change
    of behavior when using `Date` instances as they are directly converted to
    `ActiveSupport::TimeWithZone` instances without first being converted to
    `Time` instances. For example:

        # Rails 3.2 behavior
        >> Date.today.to_time.in_time_zone
        => Wed, 13 Feb 2013 07:00:00 UTC +00:00

        # Rails 4.0 behavior
        >> Date.today.in_time_zone
        => Wed, 13 Feb 2013 00:00:00 UTC +00:00

    On the plus side it now behaves the same whether you pass a `String` date
    or an actual `Date` instance. For example:

        # Rails 3.2 behavior
        >> Date.civil(2013, 2, 13).to_time.in_time_zone
        => Wed, 13 Feb 2013 07:00:00 UTC +00:00
        >> Time.zone.parse("2013-02-13")
        => Wed, 13 Feb 2013 00:00:00 UTC +00:00

        # Rails 4.0 behavior
        >> Date.civil(2013, 2, 13).in_time_zone
        => Wed, 13 Feb 2013 00:00:00 UTC +00:00
        >> "2013-02-13".in_time_zone
        => Wed, 13 Feb 2013 00:00:00 UTC +00:00

    If you need the old behavior you can convert the dates to times manually.
    For example:

        >> Post.new(created_at: Date.today).created_at
        => Wed, 13 Feb 2013 00:00:00 UTC +00:00

        >> Post.new(created_at: Date.today.to_time).created_at
        => Wed, 13 Feb 2013 07:00:00 UTC +00:00

    *Andrew White*

*   Preloading `has_many :through` associations with conditions won't
    cache the `:through` association. This will prevent invalid
    subsets to be cached.
    Fixes #8423.

    Example:

        class User
          has_many :posts
          has_many :recent_comments, -> { where('created_at > ?', 1.week.ago) }, :through => :posts
        end

        a_user = User.includes(:recent_comments).first

        # This is preloaded.
        a_user.recent_comments

        # This is not preloaded, fetched now.
        a_user.posts

    *Yves Senn*

*   Don't run `after_commit` callbacks when creating through an association
    if saving the record fails.

    *James Miller*

*   Allow store accessors to be overridden like other attribute methods, e.g.:

        class User < ActiveRecord::Base
          store :settings, accessors: [ :color, :homepage ], coder: JSON

          def color
            super || 'red'
          end
        end

    *Sergey Nartimov*

*   Quote numeric values being compared to non-numeric columns. Otherwise,
    in some database, the string column values will be coerced to a numeric
    allowing 0, 0.0 or false to match any string starting with a non-digit.

    Example:

        App.where(apikey: 0) # => SELECT * FROM users WHERE apikey = '0'

    *Dylan Smith*

*   Schema dumper supports dumping the enabled database extensions to `schema.rb`
    (currently only supported by PostgreSQL).

    *Justin George*

*   The database adapters now converts the options passed thought `DATABASE_URL`
    environment variable to the proper Ruby types before using. For example, SQLite requires
    that the timeout value is an integer, and PostgreSQL requires that the
    prepared_statements option is a boolean. These now work as expected:

    Example:

        DATABASE_URL=sqlite3://localhost/test_db?timeout=500
        DATABASE_URL=postgresql://localhost/test_db?prepared_statements=false

    *Aaron Stone + Rafael Mendonça França*

*   `Relation#merge` now only overwrites where values on the LHS of the
    merge. Consider:

        left  = Person.where(age: [13, 14, 15])
        right = Person.where(age: [13, 14]).where(age: [14, 15])

    `left` results in the following SQL:

        WHERE age IN (13, 14, 15)

    `right` results in the following SQL:

        WHERE age IN (13, 14) AND age IN (14, 15)

    Previously, `left.merge(right)` would result in all but the last
    condition being removed:

        WHERE age IN (14, 15)

    Now it results in the LHS condition(s) for `age` being removed, but
    the RHS remains as it is:

        WHERE age IN (13, 14) AND age IN (14, 15)

    *Jon Leighton*

*   Fix handling of dirty time zone aware attributes

    Previously, when `time_zone_aware_attributes` were enabled, after
    changing a datetime or timestamp attribute and then changing it back
    to the original value, `changed_attributes` still tracked the
    attribute as changed. This caused `[attribute]_changed?` and
    `changed?` methods to return true incorrectly.

    Example:

        in_time_zone 'Paris' do
          order = Order.new
          original_time = Time.local(2012, 10, 10)
          order.shipped_at = original_time
          order.save
          order.changed? # => false

          # changing value
          order.shipped_at = Time.local(2013, 1, 1)
          order.changed? # => true

          # reverting to original value
          order.shipped_at = original_time
          order.changed? # => false, used to return true
        end

    *Lilibeth De La Cruz*

*   When `#count` is used in conjunction with `#uniq` we perform `count(:distinct => true)`.
    Fixes #6865.

    Example:

        relation.uniq.count # => SELECT COUNT(DISTINCT *)

    *Yves Senn + Kaspar Schiess*

*   PostgreSQL ranges type support. Includes: int4range, int8range,
    numrange, tsrange, tstzrange, daterange

    Ranges can be created with inclusive and exclusive bounds.

    Example:

        create_table :Room do |t|
          t.daterange :availability
        end

        Room.create(availability: (Date.today..Float::INFINITY))
        Room.first.availability # => Wed, 19 Sep 2012..Infinity

    One thing to note: Range class does not support exclusive lower
    bound.

    *Alexander Grebennik*

*   Added a state instance variable to each transaction. Will allow other objects
    to know whether a transaction has been committed or rolled back.

    *John Wang*

*   Collection associations `#empty?` always respects built records.
    Fixes #8879.

    Example:

        widget = Widget.new
        widget.things.build
        widget.things.empty? # => false

    *Yves Senn*

*   Support for PostgreSQL's `ltree` data type.

    *Rob Worley*

*   Fix undefined method `to_i` when calling `new` on a scope that uses an
    Array; Fix FloatDomainError when setting integer column to NaN.
    Fixes #8718, #8734, #8757.

    *Jason Stirk + Tristan Harward*

*   Rename `update_attributes` to `update`, keep `update_attributes` as an alias for `update` method.
    This is a soft-deprecation for `update_attributes`, although it will still work without any
    deprecation message in 4.0 is recommended to start using `update` since `update_attributes` will be
    deprecated and removed in future versions of Rails.

    *Amparo Luna + Guillermo Iguaran*

*   `after_commit` and `after_rollback` now validate the `:on` option and raise an `ArgumentError`
    if it is not one of `:create`, `:destroy` or `:update`

    *Pascal Friederich*

*   Improve ways to write `change` migrations, making the old `up` & `down` methods no longer necessary.

    * The methods `drop_table` and `remove_column` are now reversible, as long as the necessary information is given.
      The method `remove_column` used to accept multiple column names; instead use `remove_columns` (which is not reversible).
      The method `change_table` is also reversible, as long as its block doesn't call `remove`, `change` or `change_default`

    * New method `reversible` makes it possible to specify code to be run when migrating up or down.
      See the [Guide on Migration](https://github.com/rails/rails/blob/master/guides/source/migrations.md#using-the-reversible-method)

    * New method `revert` will revert a whole migration or the given block.
      If migrating down, the given migration / block is run normally.
      See the [Guide on Migration](https://github.com/rails/rails/blob/master/guides/source/migrations.md#reverting-previous-migrations)

    Attempting to revert the methods `execute`, `remove_columns` and `change_column` will now
    raise an `IrreversibleMigration` instead of actually executing them without any output.

    *Marc-André Lafortune*

*   Serialized attributes can be serialized in integer columns.
    Fixes #8575.

    *Rafael Mendonça França*

*   Keep index names when using `alter_table` with sqlite3.
    Fixes #3489.

    *Yves Senn*

*   Add ability for PostgreSQL adapter to disable user triggers in `disable_referential_integrity`.
    Fixes #5523.

    *Gary S. Weaver*

*   Added support for `validates_uniqueness_of` in PostgreSQL array columns.
    Fixes #8075.

    *Pedro Padron*

*   Allow int4range and int8range columns to be created in PostgreSQL and properly convert to/from database.

    *Alexey Vasiliev aka leopard*

*   Do not log the binding values for binary columns.

    *Matthew M. Boedicker*

*   Fix counter cache columns not updated when replacing `has_many :through`
    associations.

    *Matthew Robertson*

*   Recognize migrations placed in directories containing numbers and 'rb'.
    Fixes #8492.

    *Yves Senn*

*   Add `ActiveRecord::Base.cache_timestamp_format` class attribute to control
    the format of the timestamp value in the cache key. Defaults to `:nsec`.
    Fixes #8195.

    *Rafael Mendonça França*

*   Session variables can be set for the `mysql`, `mysql2`, and `postgresql` adapters
    in the `variables: <hash>` parameter in `config/database.yml`. The key-value pairs of this
    hash will be sent in a `SET key = value` query on new database connections. See also:
    http://dev.mysql.com/doc/refman/5.0/en/set-statement.html
    http://www.postgresql.org/docs/8.3/static/sql-set.html

    *Aaron Stone*

*   Allow setting of all libpq connection parameters through the PostgreSQL adapter. See also:
    http://www.postgresql.org/docs/9.2/static/libpq-connect.html#LIBPQ-PARAMKEYWORDS

    *Lars Kanis*

*   Allow `Relation#where` with no arguments to be chained with new `not` query method.

    Example:

        Developer.where.not(name: 'Aaron')

    *Akira Matsuda*

*   Unscope `update_column(s)` query to ignore default scope.

    When applying `default_scope` to a class with a where clause, using
    `update_column(s)` could generate a query that would not properly update
    the record due to the where clause from the `default_scope` being applied
    to the update query.

        class User < ActiveRecord::Base
          default_scope -> { where(active: true) }
        end

        user = User.first
        user.active = false
        user.save!

        user.update_column(:active, true) # => false

    In this situation we want to skip the default_scope clause and just
    update the record based on the primary key. With this change:

        user.update_column(:active, true) # => true

    Fixes #8436.

    *Carlos Antonio da Silva*

*   SQLite adapter no longer corrupts binary data if the data contains `%00`.

    *Chris Feist*

*   Fix performance problem with `primary_key` method in PostgreSQL adapter when having many schemas.
    Uses `pg_constraint` table instead of `pg_depend` table which has many records in general.
    Fixes #8414.

    *kennyj*

*   Do not instantiate intermediate Active Record objects when eager loading.
    These records caused `after_find` to run more than expected.
    Fixes #3313.

    *Yves Senn*

*   Add STI support to init and building associations.
    Allows you to do `BaseClass.new(type: "SubClass")` as well as
    `parent.children.build(type: "SubClass")` or `parent.build_child`
    to initialize an STI subclass. Ensures that the class name is a
    valid class and that it is in the ancestors of the super class
    that the association is expecting.

    *Jason Rush*

*   Observers was extracted from Active Record as `rails-observers` gem.

    *Rafael Mendonça França*

*   Ensure that associations take a symbol argument. *Steve Klabnik*

*   Fix dirty attribute checks for `TimeZoneConversion` with nil and blank
    datetime attributes. Setting a nil datetime to a blank string should not
    result in a change being flagged.
    Fixes #8310.

    *Alisdair McDiarmid*

*   Prevent mass assignment to the type column of polymorphic associations when using `build`
    Fixes #8265.

    *Yves Senn*

*   Deprecate calling `Relation#sum` with a block. To perform a calculation over
    the array result of the relation, use `to_a.sum(&block)`.

    *Carlos Antonio da Silva*

*   Fix PostgreSQL adapter to handle BC timestamps correctly

        HistoryEvent.create!(name: "something", occured_at: Date.new(0) - 5.years)

    *Bogdan Gusiev*

*   When running migrations on PostgreSQL, the `:limit` option for `binary` and `text` columns is silently dropped.
    Previously, these migrations caused sql exceptions, because PostgreSQL doesn't support limits on these types.

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
    Fixes #7993.

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
    Fixes #6951.

    *kennyj*

*   Fix bug where `update_columns` and `update_column` would not let you update the primary key column.

    *Henrik Nyh*

*   The `create_table` method raises an `ArgumentError` when the primary key column is redefined.
    Fixes #6378.

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
    Fixes #5920.

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
    Fixes #7822.

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
    Fixes #6971.

        User.where(token: {})

    Before:

        #=> SELECT * FROM users;

    After:

        #=> SELECT * FROM users WHERE 1=0;

    *Damien Mathieu*

*   Fix creation of through association models when using `collection=[]`
    on a `has_many :through` association from an unsaved model.
    Fixes #7661.

    *Ernie Miller*

*   Explain only normal CRUD sql (select / update / insert / delete).
    Fix problem that explains unexplainable sql.
    Fixes #7544 #6458.

    *kennyj*

*   You can now override the generated accessor methods for stored attributes
    and reuse the original behavior with `read_store_attribute` and `write_store_attribute`,
    which are counterparts to `read_attribute` and `write_attribute`.

    *Matt Jones*

*   Accept `belongs_to` (including polymorphic) association keys in queries.

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

*   Changed `validates_presence_of` on an association so that children objects
    do not validate as being present if they are marked for destruction. This
    prevents you from saving the parent successfully and thus putting the parent
    in an invalid state.

    *Nick Monje & Brent Wheeldon*

*   `FinderMethods#exists?` now returns `false` with the `false` argument.

    *Egor Lynko*

*   Added support for specifying the precision of a timestamp in the PostgreSQL
    adapter. So, instead of having to incorrectly specify the precision using the
    `:limit` option, you may use `:precision`, as intended. For example, in a migration:

        def change
          create_table :foobars do |t|
            t.timestamps precision: 0
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
    to when the association is built. This is consistent with other association
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
        person.pets.delete(2, 3) # => [#<Pet id: 2>, #<Pet id: 3>]

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

    The code to implement the deprecated features has been moved out to the
    `activerecord-deprecated_finders` gem. This gem is a dependency of Active
    Record in Rails 4.0, so the interface works out of the box. It will no
    longer be a dependency from Rails 4.1 (you'll need to add it to the
    `Gemfile` in 4.1), and will be maintained until Rails 5.0.

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

    `Schema cache dump` feature was implemented. This feature can dump/load internal state of `SchemaCache` instance
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

    generates

        CREATE INDEX index_accounts_on_code ON accounts(code) WHERE active

    *Marcelo Silveira*

*   Implemented `ActiveRecord::Relation#none` method.

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

        Post.includes(:comments).where(comments: { name: 'foo' })
        Post.includes(:comments).where('comments.name' => 'foo')
        Post.includes(:comments).order('comments.name')

    You do not need to worry about this unless you are doing eager
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
