*   The BEGIN template annotation/comment is printed on the same line
    with other element tags. This PR fixes that by moving the comment to its own line.

    Before:

    ```
    <!-- BEGIN /Users/siaw23/Desktop/rails/actionview/test/fixtures/actionpack/test/greeting.html.erb --><p>This is grand!</p>
    ```

    After:

    ```
    <!-- BEGIN /Users/siaw23/Desktop/rails/actionview/test/fixtures/actionpack/test/greeting.html.erb -->
    <p>This is grand!</p>
    ```

    *Emmanuel Hayford*

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
