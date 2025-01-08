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

*   Improve error highlighting of multi-line methods in ERB templates or
    templates where the error occurs within a do-end block.

    *Martin Emde*

*   Fix a crash in ERB template error highlighting when the error occurs on a
    line in the compiled template that is past the end of the source template.

    *Martin Emde*

*   Improve reliability of ERB template error highlighting.
    Fix infinite loops and crashes in highlighting and
    improve tolerance for alternate ERB handlers.

    *Martin Emde*

*   Allow `hidden_field` and `hidden_field_tag` to accept a custom autocomplete value.

    *brendon*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actionview/CHANGELOG.md) for previous changes.
