*   Introduce `config.action_view.html_assertions`

    Adds support for testing with `Capybara::Minitest::Assertions` when set to `:capybara`.
    Defaults to `Rails::Dom::Testing::Assertions` with `:rails_dom_testing`.

    *Sean Doyle*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
