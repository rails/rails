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

*   Add `expires_in:` option to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
