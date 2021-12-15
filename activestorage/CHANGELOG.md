*   Support transforming empty-ish `has_many_attached` value into `[]` (e.g. `[""]`)

    ```ruby
    @user.highlights = [""]
    @user.highlights # => []
    ```

    *Sean Doyle*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activestorage/CHANGELOG.md) for previous changes.
