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

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
