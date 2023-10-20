*   Remove warning message when running SQLite in production

    SQLite is becoming a more capable database and there are more companies using it in production.
    It's really good for self-hosted/small environments where you don't want to boot a
    separate server for the DB. There's no more need to discourage his usage via a warning.

    *Jacopo Beschi*

*   Include `ActiveModel::API` in `ActiveRecord::Base`

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
