*   "Backport" `ActiveRecord::Persistence.create!` and `.create` to `ActiveModel::Persistence`

    Extract `.create!` and `.create` into `ActiveModel::Persistence`, then
    include in `ActiveRecord::Persistence`.

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
