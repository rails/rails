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

## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Enable DependencyTracker to evaluate renders with trailing interpolation.

    ```erb
    <%= render "maintenance_tasks/runs/info/#{run.status}" %>
    ```

    Previously, the DependencyTracker would ignore this render, but now it will
    mark all partials in the "maintenance_tasks/runs/info" folder as
    dependencies.

    *Hartley McGuire*

*   Rename `text_area` methods into `textarea`

    Old names are still available as aliases.

    *Sean Doyle*

*   Rename `check_box*` methods into `checkbox*`.

    Old names are still available as aliases.

    *Jean Boussier*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
