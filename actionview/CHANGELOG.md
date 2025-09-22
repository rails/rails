## Rails 8.0.3 (September 22, 2025) ##

*   Fix label with `for` option not getting prefixed by form `namespace` value

    *Abeid Ahmed*, *Hartley McGuire*

*   Fix `javascript_include_tag` `type` option to accept either strings and symbols.

    ```ruby
    javascript_include_tag "application", type: :module
    javascript_include_tag "application", type: "module"
    ```

    Previously, only the string value was recognized.

    *Jean Boussier*

*   Fix `excerpt` helper with non-whitespace separator.

    *Jonathan Hefner*


## Rails 8.0.2.1 (August 13, 2025) ##

*   No changes.


## Rails 8.0.2 (March 12, 2025) ##

*   Respect `html_options[:form]` when `collection_checkboxes` generates the
    hidden `<input>`.

    *Riccardo Odone*

*   Layouts have access to local variables passed to `render`.

    This fixes #31680 which was a regression in Rails 5.1.

    *Mike Dalessio*

*   Argument errors related to strict locals in templates now raise an
    `ActionView::StrictLocalsError`, and all other argument errors are reraised as-is.

    Previously, any `ArgumentError` raised during template rendering was swallowed during strict
    local error handling, so that an `ArgumentError` unrelated to strict locals (e.g., a helper
    method invoked with incorrect arguments) would be replaced by a similar `ArgumentError` with an
    unrelated backtrace, making it difficult to debug templates.

    Now, any `ArgumentError` unrelated to strict locals is reraised, preserving the original
    backtrace for developers.

    Also note that `ActionView::StrictLocalsError` is a subclass of `ArgumentError`, so any existing
    code that rescues `ArgumentError` will continue to work.

    Fixes #52227.

    *Mike Dalessio*

*   Fix stack overflow error in dependency tracker when dealing with circular dependencies

    *Jean Boussier*

## Rails 8.0.1 (December 13, 2024) ##

*   Fix a crash in ERB template error highlighting when the error occurs on a
    line in the compiled template that is past the end of the source template.

    *Martin Emde*

*   Improve reliability of ERB template error highlighting.
    Fix infinite loops and crashes in highlighting and
    improve tolerance for alternate ERB handlers.

    *Martin Emde*


## Rails 8.0.0.1 (December 10, 2024) ##

*   No changes.


## Rails 8.0.0 (November 07, 2024) ##

*   No changes.


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   No changes.


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   Remove deprecated support to passing a content to void tag elements on the `tag` builder.

    *Rafael Mendonça França*

*   Remove deprecated support to passing `nil` to the `model:` argument of `form_with`.

    *Rafael Mendonça França*


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
