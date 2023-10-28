*   Add `#destroy_all!` method to `ActiveRecord::Relation`

    If the `before_destroy` callback throws abort the action is cancelled and `destroy_all!` raises `ActiveRecord::RecordNotDestroyed`.

    If you have multiple target records and want to ensure that all records are deleted, you must accomplish this by explicitly using a transaction to perform a rollback, as shown below:

    ```ruby
    class User < ApplicationRecord
      before_destroy do
        throw :abort if id == 3
      end
    end

    ActiveRecord::Base.transaction do
      User.where(id: 1..3).destroy_all!
    end
    ```

    *Shodai Suzuki*

*   Include `ActiveModel::API` in `ActiveRecord::Base`

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
