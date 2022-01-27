*   Include closing `</form>` tag when calling `form_with` without a block:

    ```ruby
    form_with url: "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields -->

    config.action_view.close_form_with_without_block = true

    form_with url: "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields --></form>
    ```

    *Sean Doyle*

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
