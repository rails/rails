*   Support multiple preview paths for mailers.

    Option `config.action_mailer.preview_path` is deprecated in favor of
    `config.action_mailer.preview_paths`. Appending paths to this configuration option will cause
    those paths to be used in the search for mailer previews.

    *fatkodima*

*   Configures a default of 5 for both `open_timeout` and `read_timeout` for SMTP Settings.

    *André Luis Leal Cardoso Junior*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionmailer/CHANGELOG.md) for previous changes.
