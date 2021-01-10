*   Add `ActiveRecord::Migration.after_migrate_hook` which gets called after migrations

    Example use case, store migration logs on external storage after migrations:

    ```ruby
    ActiveRecord::Migration.after_migrate_hook = -> (log, name, direction, error) do
      upload_to_storage(log, name, direction) unless error
    end
    ```

    *Yoann Lecuyer* (porting code from Jordan Thiercelin)

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
