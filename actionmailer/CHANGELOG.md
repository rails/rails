*   Add `config.action_mailer.show_previews` configuration option.

    This config option can be used to enable the mail preview in environments
    other than development (such as staging).

    Defaults to `true` in development and false elsewhere.

    *Leonard Garvey*

*   Allow preview interceptors to be registered through
    `config.action_mailer.preview_interceptors`.

    See #15739.

    *Yves Senn*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionmailer/CHANGELOG.md) for previous changes.
