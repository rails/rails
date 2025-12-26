*   Introduce `field_label` form helper

    Generate the text-only label contents for a field:

    ```ruby
    # Helper method
    field_label :article, :title    # => "Title"

    # FormBuilder method
    fields model: @article do |form|
      form.label :title             # => "<label for=\"article_title\">Title</label>"
      form.field_label :title       # => "Title"
    end
    ```

    *Sean Doyle*

*   Fix tag parameter content being overwritten instead of combined with tag block content.
    Before `tag.div("Hello ") { "World" }` would just return `<div>World</div>`, now it returns `<div>Hello World</div>`.

    *DHH*

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
