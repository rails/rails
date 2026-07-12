*   Honor `template_path:` in block-form `mail`.

    Passing `template_path:` to the block form of `mail` was ignored, so the
    implicitly rendered template was always looked up under the mailer's
    default path. It is now honored, matching the non-block form.

    *Kenta Ishizaki*

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
