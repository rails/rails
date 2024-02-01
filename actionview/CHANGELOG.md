*   Enable DependencyTracker to evaluate renders with trailing interpolation.

    ```erb
    <%= render "maintenance_tasks/runs/info/#{run.status}" %>
    ```

    Previously, the DependencyTracker would ignore this render, but now it will
    mark all partials in the "maintenance_tasks/runs/info" folder as
    dependencies.

    *Hartley McGuire*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
