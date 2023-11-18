*   Introduce `config.action_mailer.html_assertions`

    Adds support for testing with `Capybara::Minitest::Assertions` when set to `:capybara`.
    Defaults to `Rails::Dom::Testing::Assertions` with `:rails_dom_testing`.

    *Sean Doyle*

*   Remove deprecated params via `:args` for `assert_enqueued_email_with`.

    *Rafael Mendonça França*

*   Remove deprecated `config.action_mailer.preview_path`.

    *Rafael Mendonça França*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionmailer/CHANGELOG.md) for previous changes.
