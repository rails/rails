*   Introduce `#assert_html_part` and `#assert_text_part` to `ActionMailer::TestCase`

    ```ruby
    test "assert MyMailer.welcome HTML and text parts" do
      mail = MyMailer.welcome("Hello, world")

      assert_html_part mail do
        assert_select "p", "Hello, world"
      end
      assert_text_part mail do |text|
        assert_includes text, "Hello, world"
      end
    end
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actionmailer/CHANGELOG.md) for previous changes.
