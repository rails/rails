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
