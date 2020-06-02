*   Add method to confirm rich text content existence by adding `?` after rich
    text attribute.

    ```ruby
    message = Message.create!(body: "<h1>Funny times!</h1>")
    message.body? #=> true
    ```

    *Kyohei Toyoda*

*   The `fill_in_rich_text_area` system test helper locates a Trix editor
    and fills it in with the given HTML.

    ```ruby
    # <trix-editor id="message_content" ...></trix-editor>
    fill_in_rich_text_area "message_content", with: "Hello <em>world!</em>"

    # <trix-editor placeholder="Your message here" ...></trix-editor>
    fill_in_rich_text_area "Your message here", with: "Hello <em>world!</em>"

    # <trix-editor aria-label="Message content" ...></trix-editor>
    fill_in_rich_text_area "Message content", with: "Hello <em>world!</em>"

    # <input id="trix_input_1" name="message[content]" type="hidden">
    # <trix-editor input="trix_input_1"></trix-editor>
    fill_in_rich_text_area "message[content]", with: "Hello <em>world!</em>"
    ```

    *George Claghorn*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actiontext/CHANGELOG.md) for previous changes.
