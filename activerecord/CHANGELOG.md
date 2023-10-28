*   Add `set_constraints` helper for PostgreSQL

    ```ruby
    Post.create!(user_id: -1) # => ActiveRecord::InvalidForeignKey

    Post.transaction do
      Post.connection.set_constraints(:deferred)
      p = Post.create!(user_id: -1)
      u = User.create!
      p.user = u
      p.save!
    end
    ```

    *Cody Cutrer*

*   Include `ActiveModel::API` in `ActiveRecord::Base`

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
