*   Add `reset_tag` helper method to reset the form tag state.

    This method is useful when you want to reset the form tag state to the default values.

    ```erb
    <%= reset_tag %>
    <%= reset_tag('Clear Form') %>
    <%= reset_tag('Reset', class: 'btn btn-secondary') %>
    ```

    *Akhil G Krishnan*

*   Rename `text_area` methods into `textarea`

    Old names are still available as aliases.

    *Sean Doyle*

*   Rename `check_box*` methods into `checkbox*`.

    Old names are still available as aliases.

    *Jean Boussier*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
