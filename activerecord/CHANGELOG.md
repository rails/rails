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
