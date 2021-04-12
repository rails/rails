*   Add `update_sql` option to `#upsert_all` to make it possible to use raw SQL to update columns on conflict:

    ```ruby
    Book.upsert_all(
      [{ id: 1, status: 1 }, { id: 2, status: 1 }],
      update_sql: "status = GREATEST(books.status, EXCLUDED.status)"
    )
    ```

    *Vladimir Dementyev*

*   Allow passing raw SQL as `returning` statement to `#upsert_all`:

    ```ruby
    Article.insert_all(
    [
        {title: "Article 1", slug: "article-1", published: false},
        {title: "Article 2", slug: "article-2", published: false}
      ],
      # Some PostgreSQL magic here to detect which rows have been actually inserted
      returning: "id, (xmax = '0') as inserted, name as new_name"
    )
    ```

    *Vladimir Dementyev*

*   Deprecate `legacy_connection_handling`.

    *Eileen M. Uchitelle*

*   Add attribute encryption support.

    Encrypted attributes are declared at the model level. These
    are regular Active Record attributes backed by a column with
    the same name. The system will transparently encrypt these
    attributes before saving them into the database and will
    decrypt them when retrieving their values.


    ```ruby
    class Person < ApplicationRecord
      encrypts :name
      encrypts :email_address, deterministic: true
    end
    ```

    You can learn more in the [Active Record Encryption
    guide](https://edgeguides.rubyonrails.org/active_record_encryption.html).

    *Jorge Manrubia*

*   Changed Arel predications `contains` and `overlaps` to use
    `quoted_node` so that PostgreSQL arrays are quoted properly.

    *Bradley Priest*

*   Add mode argument to record level `strict_loading!`

    This argument can be used when enabling strict loading for a single record
    to specify that we only want to raise on n plus one queries.

    ```ruby
    developer.strict_loading!(mode: :n_plus_one_only)

    developer.projects.to_a # Does not raise
    developer.projects.first.client # Raises StrictLoadingViolationError
    ```

    Previously, enabling strict loading would cause any lazily loaded
    association to raise an error. Using `n_plus_one_only` mode allows us to
    lazily load belongs_to, has_many, and other associations that are fetched
    through a single query.

    *Dinah Shi*

*   Fix Float::INFINITY assignment to datetime column with postgresql adapter

    Before:

    ```ruby
    # With this config
    ActiveRecord::Base.time_zone_aware_attributes = true

    # and the following schema:
    create_table "postgresql_infinities" do |t|
      t.datetime "datetime"
    end

    # This test fails
    record = PostgresqlInfinity.create!(datetime: Float::INFINITY)
    assert_equal Float::INFINITY, record.datetime # record.datetime gets nil
    ```

    After this commit, `record.datetime` gets `Float::INFINITY` as expected.

    *Shunichi Ikegami*

*   Type cast enum values by the original attribute type.

    The notable thing about this change is that unknown labels will no longer match 0 on MySQL.

    ```ruby
    class Book < ActiveRecord::Base
      enum :status, { proposed: 0, written: 1, published: 2 }
    end
    ```

    Before:

    ```ruby
    # SELECT `books`.* FROM `books` WHERE `books`.`status` = 'prohibited' LIMIT 1
    Book.find_by(status: :prohibited)
    # => #<Book id: 1, status: "proposed", ...> (for mysql2 adapter)
    # => ActiveRecord::StatementInvalid: PG::InvalidTextRepresentation: ERROR:  invalid input syntax for type integer: "prohibited" (for postgresql adapter)
    # => nil (for sqlite3 adapter)
    ```

    After:

    ```ruby
    # SELECT `books`.* FROM `books` WHERE `books`.`status` IS NULL LIMIT 1
    Book.find_by(status: :prohibited)
    # => nil (for all adapters)
    ```

    *Ryuta Kamizono*

*   Fixtures for `has_many :through` associations now load timestamps on join tables

    Given this fixture:

    ```yml
    ### monkeys.yml
    george:
      name: George the Monkey
      fruits: apple

    ### fruits.yml
    apple:
      name: apple
    ```

    If the join table (`fruit_monkeys`) contains `created_at` or `updated_at` columns,
    these will now be populated when loading the fixture. Previously, fixture loading
    would crash if these columns were required, and leave them as null otherwise.

    *Alex Ghiculescu*

*   Allow applications to configure the thread pool for async queries

    Some applications may want one thread pool per database whereas others want to use
    a single global thread pool for all queries. By default, Rails will set `async_query_executor`
    to `nil` which will not initialize any executor. If `load_async` is called and no executor
    has been configured, the query will be executed in the foreground.

    To create one thread pool for all database connections to use applications can set
    `config.active_record.async_query_executor` to `:global_thread_pool` and optionally define
    `config.active_record.global_executor_concurrency`. This defaults to 4. For applications that want
    to have a thread pool for each database connection, `config.active_record.async_query_executor` can
    be set to `:multi_thread_pool`. The configuration for each thread pool is set in the database
    configuration.

    *Eileen M. Uchitelle*

*   Allow new syntax for `enum` to avoid leading `_` from reserved options.

    Before:

    ```ruby
    class Book < ActiveRecord::Base
      enum status: [ :proposed, :written ], _prefix: true, _scopes: false
      enum cover: [ :hard, :soft ], _suffix: true, _default: :hard
    end
    ```

    After:

    ```ruby
    class Book < ActiveRecord::Base
      enum :status, [ :proposed, :written ], prefix: true, scopes: false
      enum :cover, [ :hard, :soft ], suffix: true, default: :hard
    end
    ```

    *Ryuta Kamizono*

*   Add `ActiveRecord::Relation#load_async`.

    This method schedules the query to be performed asynchronously from a thread pool.

    If the result is accessed before a background thread had the opportunity to perform
    the query, it will be performed in the foreground.

    This is useful for queries that can be performed long enough before their result will be
    needed, or for controllers which need to perform several independent queries.

    ```ruby
    def index
      @categories = Category.some_complex_scope.load_async
      @posts = Post.some_complex_scope.load_async
    end
    ```

    *Jean Boussier*

*   Implemented `ActiveRecord::Relation#excluding` method.

    This method excludes the specified record (or collection of records) from
    the resulting relation:

    ```ruby
    Post.excluding(post)
    Post.excluding(post_one, post_two)
    ```

    Also works on associations:

    ```ruby
    post.comments.excluding(comment)
    post.comments.excluding(comment_one, comment_two)
    ```

    This is short-hand for `Post.where.not(id: post.id)` (for a single record)
    and `Post.where.not(id: [post_one.id, post_two.id])` (for a collection).

    *Glen Crawford*

*   Skip optimised #exist? query when #include? is called on a relation
    with a having clause

    Relations that have aliased select values AND a having clause that
    references an aliased select value would generate an error when
    #include? was called, due to an optimisation that would generate
    call #exists? on the relation instead, which effectively alters
    the select values of the query (and thus removes the aliased select
    values), but leaves the having clause intact. Because the having
    clause is then referencing an aliased column that is no longer
    present in the simplified query, an ActiveRecord::InvalidStatement
    error was raised.

    A sample query affected by this problem:

    ```ruby
    Author.select('COUNT(*) as total_posts', 'authors.*')
          .joins(:posts)
          .group(:id)
          .having('total_posts > 2')
          .include?(Author.first)
    ```

    This change adds an addition check to the condition that skips the
    simplified #exists? query, which simply checks for the presence of
    a having clause.

    Fixes #41417

    *Michael Smart*

*   Increment postgres prepared statement counter before making a prepared statement, so if the statement is aborted
    without Rails knowledge (e.g., if app gets killed during long-running query or due to Rack::Timeout), app won't end
    up in perpetual crash state for being inconsistent with Postgres.

    *wbharding*, *Martin Tepper*

*   Add ability to apply `scoping` to `all_queries`.

    Some applications may want to use the `scoping` method but previously it only
    worked on certain types of queries. This change allows the `scoping` method to apply
    to all queries for a model in a block.

    ```ruby
    Post.where(blog_id: post.blog_id).scoping(all_queries: true) do
      post.update(title: "a post title") # adds `posts.blog_id = 1` to the query
    end
    ```

    *Eileen M. Uchitelle*

*   `ActiveRecord::Calculations.calculate` called with `:average`
    (aliased as `ActiveRecord::Calculations.average`) will now use column based
    type casting. This means that floating-point number columns will now be
    aggregated as `Float` and decimal columns will be aggregated as `BigDecimal`.

    Integers are handled as a special case returning `BigDecimal` always
    (this was the case before already).

    ```ruby
    # With the following schema:
    create_table "measurements" do |t|
      t.float "temperature"
    end

    # Before:
    Measurement.average(:temperature).class
    # => BigDecimal

    # After:
    Measurement.average(:temperature).class
    # => Float
    ```

    Before this change, Rails just called `to_d` on average aggregates from the
    database adapter. This is not the case anymore. If you relied on that kind
    of magic, you now need to register your own `ActiveRecord::Type`
    (see `ActiveRecord::Attributes::ClassMethods` for documentation).

    *Josua Schmid*

*   PostgreSQL: handle `timestamp with time zone` columns correctly in `schema.rb`.

    Previously they dumped as `t.datetime :column_name`, now they dump as `t.timestamptz :column_name`,
    and are created as `timestamptz` columns when the schema is loaded.

    *Alex Ghiculescu*

*   Removing trailing whitespace when matching columns in
    `ActiveRecord::Sanitization.disallow_raw_sql!`.

    *Gannon McGibbon*, *Adrian Hirt*

*   Expose a way for applications to set a `primary_abstract_class`

    Multiple database applications that use a primary abstract class that is not
    named `ApplicationRecord` can now set a specific class to be the `primary_abstract_class`.

    ```ruby
    class PrimaryApplicationRecord
      self.primary_abstract_class
    end
    ```

    When an application boots it automatically connects to the primary or first database in the
    database configuration file. In a multiple database application that then call `connects_to`
    needs to know that the default connection is the same as the `ApplicationRecord` connection.
    However, some applications have a differently named `ApplicationRecord`. This prevents Active
    Record from opening duplicate connections to the same database.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Support hash config for `structure_dump_flags` and `structure_load_flags` flags
    Now that Active Record supports multiple databases configuration
    we need a way to pass specific flags for dump/load databases since
    the options are not the same for different adapters.
    We can use in the original way:

    ```ruby
    ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ['--no-defaults', '--skip-add-drop-table']
    #or
    ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = '--no-defaults --skip-add-drop-table'
    ```

    And also use it passing a hash, with one or more keys, where the key
    is the adapter

    ```ruby
    ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = {
      mysql2: ['--no-defaults', '--skip-add-drop-table'],
      postgres: '--no-tablespaces'
    }
    ```

    *Gustavo Gonzalez*

*   Connection specification now passes the "url" key as a configuration for the
    adapter if the "url" protocol is "jdbc", "http", or "https". Previously only
    urls with the "jdbc" prefix were passed to the Active Record Adapter, others
    are assumed to be adapter specification urls.

    Fixes #41137.

    *Jonathan Bracy*

*   Allow to opt-out of `strict_loading` mode on a per-record base.

    This is useful when strict loading is enabled application wide or on a
    model level.

    ```ruby
    class User < ApplicationRecord
      has_many :bookmarks
      has_many :articles, strict_loading: true
    end

    user = User.first
    user.articles                        # => ActiveRecord::StrictLoadingViolationError
    user.bookmarks                       # => #<ActiveRecord::Associations::CollectionProxy>

    user.strict_loading!(true)           # => true
    user.bookmarks                       # => ActiveRecord::StrictLoadingViolationError

    user.strict_loading!(false)          # => false
    user.bookmarks                       # => #<ActiveRecord::Associations::CollectionProxy>
    user.articles.strict_loading!(false) # => #<ActiveRecord::Associations::CollectionProxy>
    ```

    *Ayrton De Craene*

*   Add `FinderMethods#sole` and `#find_sole_by` to find and assert the
    presence of exactly one record.

    Used when you need a single row, but also want to assert that there aren't
    multiple rows matching the condition; especially for when database
    constraints aren't enough or are impractical.

    ```ruby
    Product.where(["price = %?", price]).sole
    # => ActiveRecord::RecordNotFound      (if no Product with given price)
    # => #<Product ...>                    (if one Product with given price)
    # => ActiveRecord::SoleRecordExceeded  (if more than one Product with given price)

    user.api_keys.find_sole_by(key: key)
    # as above
    ```

    *Asherah Connor*

*   Makes `ActiveRecord::AttributeMethods::Query` respect the getter overrides defined in the model.

    Before:

    ```ruby
    class User
      def admin
        false # Overriding the getter to always return false
      end
    end

    user = User.first
    user.update(admin: true)

    user.admin # false (as expected, due to the getter overwrite)
    user.admin? # true (not expected, returned the DB column value)
    ```

    After this commit, `user.admin?` above returns false, as expected.

    Fixes #40771.

    *Felipe*

*   Allow delegated_type to be specified primary_key and foreign_key.

    Since delegated_type assumes that the foreign_key ends with `_id`,
    `singular_id` defined by it does not work when the foreign_key does
    not end with `id`. This change fixes it by taking into account
    `primary_key` and `foreign_key` in the options.

    *Ryota Egusa*

*   Expose an `invert_where` method that will invert all scope conditions.

    ```ruby
    class User
      scope :active, -> { where(accepted: true, locked: false) }
    end

    User.active
    # ... WHERE `accepted` = 1 AND `locked` = 0

    User.active.invert_where
    # ... WHERE NOT (`accepted` = 1 AND `locked` = 0)
    ```

    *Kevin Deisz*

*   Restore possibility of passing `false` to :polymorphic option of `belongs_to`.

    Previously, passing `false` would trigger the option validation logic
    to throw an error saying :polymorphic would not be a valid option.

    *glaszig*

*   Remove deprecated `database` kwarg from `connected_to`.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Allow adding nonnamed expression indexes to be revertible.

    Fixes #40732.

    Previously, the following code would raise an error, when executed while rolling back,
    and the index name should be specified explicitly. Now, the index name is inferred
    automatically.
    ```ruby
    add_index(:items, "to_tsvector('english', description)")
    ```

    *fatkodima*

*   Only warn about negative enums if a positive form that would cause conflicts exists.

    Fixes #39065.

    *Alex Ghiculescu*

*   Add option to run `default_scope` on all queries.

    Previously, a `default_scope` would only run on select or insert queries. In some cases, like non-Rails tenant sharding solutions, it may be desirable to run `default_scope` on all queries in order to ensure queries are including a foreign key for the shard (i.e. `blog_id`).

    Now applications can add an option to run on all queries including select, insert, delete, and update by adding an `all_queries` option to the default scope definition.

    ```ruby
    class Article < ApplicationRecord
      default_scope -> { where(blog_id: Current.blog.id) }, all_queries: true
    end
    ```

    *Eileen M. Uchitelle*

*   Add `where.associated` to check for the presence of an association.

    ```ruby
    # Before:
    account.users.joins(:contact).where.not(contact_id: nil)

    # After:
    account.users.where.associated(:contact)
    ```

    Also mirrors `where.missing`.

    *Kasper Timm Hansen*

*   Allow constructors (`build_association` and `create_association`) on
    `has_one :through` associations.

    *Santiago Perez Perret*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activerecord/CHANGELOG.md) for previous changes.
