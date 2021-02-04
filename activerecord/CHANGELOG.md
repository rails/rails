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
    However some applications have a differently named `ApplicationRecord`. This prevents Active
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

    Previously, a `default_scope` would only run on select or insert queries. In some cases, like non-Rails tenant sharding solutions, it may be desirable to run `default_scope` on all queries in order to ensure queries are including a foreign key for the shard (ie `blog_id`).

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
