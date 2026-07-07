*   Make Action Mailer configuration `Ractor`-shareable when `ActiveSupport::Ractors.unshareable_proc_action` is set.

    After the application has finished initializing, the relevant Action Mailer
    configuration values are made `Ractor`-shareable so they can no longer be
    mutated at runtime.

    *Gannon McGibbon*

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
