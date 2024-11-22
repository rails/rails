*   Allow setting content type with a symbol of the Mime type.

    ```ruby
    # Before
    response.content_type = "text/html"

    # After
    response.content_type = :html
    ```

    *Petrik de Heus*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actionpack/CHANGELOG.md) for previous changes.
