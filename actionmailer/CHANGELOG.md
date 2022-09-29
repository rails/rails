*   Added ability to download `.eml` file for the email preview.

    *Igor Kasyanchuk*

*   Support multiple preview paths for mailers.

    Option `config.action_mailer.preview_path` is deprecated in favor of
    `config.action_mailer.preview_paths`. Appending paths to this configuration option
    will cause those paths to be used in the search for mailer previews.

    *fatkodima*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionmailer/CHANGELOG.md) for previous changes.
