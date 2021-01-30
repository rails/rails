*   Introduce `config.action_controller.html_assertions` and `config.action_dispatch.html_assertions`

    Adds support for testing with `Capybara::Minitest::Assertions` when set to `:capybara`.
    Defaults to `Rails::Dom::Testing::Assertions` with `:rails_dom_testing`.

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionpack/CHANGELOG.md) for previous changes.
