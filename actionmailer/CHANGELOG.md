*   Add `:capybara` support for `config.action_mailer.dom_testing_assertions`

    Setting `:capybara` integrates with `Capybara::Minitest::Assertions`

    *Sean Doyle*

*   Introduce `config.action_mailer.dom_testing_assertions`

    Adds support for `:rails_dom_testing` to support `Rails::Dom::Testing::Assertions` and `:none`.
    Defaults to with `:rails_dom_testing`.

    *Sean Doyle*

*   Add support for `config.action_mailer.raise_on_missing_callback_actions`
    when using `_deliver` callbacks with `only:` and `except:` options.

    *Iaroslav*

*   Add `assert_part` and `assert_no_part` to `ActionMailer::TestCase`

    ```ruby
    test "assert MyMailer.welcome HTML and text parts" do
      mail = MyMailer.welcome("Hello, world")

      assert_part :text, mail do |text|
        assert_includes text, "Hello, world"
      end
      assert_part :html, mail do |html|
        assert_dom html.root, "p", "Hello, world"
      end
    end
    ```

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionmailer/CHANGELOG.md) for previous changes.
