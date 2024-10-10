*   Include closing `</form>` tag when calling `form_tag` and `form_with` without a block:

    ```ruby
    config.action_view.closes_form_tag_without_block = true

    form_tag "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields --></form>

    form_with url: "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields --></form>

    config.action_view.closes_form_tag_without_block = false

    form_tag "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields -->

    form_with url: "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields -->
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
