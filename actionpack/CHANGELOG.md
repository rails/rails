*   Add `racc` as a dependency since it will become a bundled gem in Ruby 3.4.0

    *Hartley McGuire*

*   Use the correct path when the resource is singular.

    Before:
    ```ruby
    edit_author_path
    # => /author.1
    ```

    After:
    ```ruby
    edit_author_path
    # => /author
    ```

    *Paul Reece*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionpack/CHANGELOG.md) for previous changes.
