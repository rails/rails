*   Deprecate `:class_name` option for the `:through` association

    Through association should always rely on the :class_name of its source
    association. Example:

    ```
    Post.has_many :commenters, through: :comments,
      source: :author, class_name: 'CommentAuthor'
    post.comments.first.author.class # => Author
    post.commenters.first.class # => CommentAuthor
    ```

    Using `:class_name` causes inconsistencies to the through association including
    some bugs in preloading that assumes that through association uses the class
    as its source association.

    *Bogdan Gusiev*

*   Fix sqlite3 collation parsing when using decimal columns.

    *Martin R. Schuster*

*   Fix invalid schema when primary key column has a comment.

    Fixes #29966.

    *Guilherme Goettems Schneider*

*   Fix table comment also being applied to the primary key column.

    *Guilherme Goettems Schneider*

*   Allow generated `create_table` migrations to include or skip timestamps.

    *Michael Duchemin*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activerecord/CHANGELOG.md) for previous changes.
