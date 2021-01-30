*   Introduce `config.action_mailer.html_assertions`

    Adds support for testing with `Capybara::Minitest::Assertions` when set to `:capybara`.
    Defaults to `Rails::Dom::Testing::Assertions` with `:rails_dom_testing`.

    *Sean Doyle*

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
