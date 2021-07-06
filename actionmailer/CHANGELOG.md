*   Allow passing an array of strings to preview_path

    This is now possible:
    ```ruby
    config.action_mailer.preview_path = [
      "#{Foo::Engine.root}/test/mailers/previews",
      "#{Bar::Engine.root}/test/mailers/previews"
    ]
    ```
    *Victor Lima Campos*

*   Configures a default of 5 for both `open_timeout` and `read_timeout` for SMTP Settings.

    *André Luis Leal Cardoso Junior*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionmailer/CHANGELOG.md) for previous changes.
