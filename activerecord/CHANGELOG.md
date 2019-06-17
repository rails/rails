*   Make ActiveRecord `ConnectionPool.connections` method thread-safe.

    Fixes #36465.

    *Jeff Doering*

*   Add support for multiple databases to `rails db:abort_if_pending_migrations`.

    *Mark Lee*

*   Fix sqlite3 collation parsing when using decimal columns.

    *Martin R. Schuster*

*   Fix invalid schema when primary key column has a comment.

    Fixes #29966.

    *Guilherme Goettems Schneider*

*   Fix table comment also being applied to the primary key column.

    *Guilherme Goettems Schneider*

*   Allow generated `create_table` migrations to include or skip timestamps.

    *Michael Duchemin*

*   Add more helpful methods for ActiveRecord::Enum.

    *Jason Lee*

    ```rb
    class Book
      enum status: %i[draft published archived]
    end

    Book.status_options # => [["Drafting", "draft"], ["Published", "published"], ["Archived", "archived"]]

    @book = Book.new(status: :draft)
    @book.status # => "draft"
    @book.status_name # => "Drafting"
    @book.status_color # => "#999999"
    @book.status_value # => 0

    @book.status = :published
    @book.status_name # => "Published"
    @book.status_color # => "green"
    @book.status_value # => 1
    ```

    Custom name, color in I18n config:

    ```yml
    en:
      activerecord:
        enums:
          book:
            status:
              draft: Drafting
              published: Published
              archived: Archived
            status_color:
              draft: "#999999"
              published: "green"
              archived: "red"
    ```

    `status_options` for select tag in Views:

    ```erb
    <%= f.select :status, Book.status_options %>
    ```

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activerecord/CHANGELOG.md) for previous changes.
