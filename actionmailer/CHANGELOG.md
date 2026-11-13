*   Require `mail` 2.9.1 and `net-imap` 0.6.4.1.

    `mail` 2.9.1 is the patched release for CVE-2026-63435. It depends
    on `net-imap` without a floor, so Action Mailer requires the
    patched IMAP client as well.

    *Alexander Patrikalakis*

*   Raise when `ActionMailer.deliver_all_later` is called with a message that was already accessed.

    Previously, the messages were enqueued and any local changes were silently lost,
    while `deliver_later` raises in the same situation.

    *Bastin*

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
