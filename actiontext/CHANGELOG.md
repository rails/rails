## Rails 6.1.1 (January 07, 2021) ##

*   No changes.


## Rails 6.1.0 (December 09, 2020) ##

*   Declare `ActionText::FixtureSet.attachment` to generate an
    `<action-text-attachment sgid="..."></action-text-attachment>` element with
    a valid `sgid` attribute.

    ```ruby
    hello_world_review_content:
      record: hello_world (Review)
      name: content
      body: <p><%= ActionText::FixtureSet.attachment("messages", :hello_world) %> is great!</p>
    ```

    *Sean Doyle*

*   Locate `fill_in_rich_text_area` by `<label>` text

    In addition to searching for `<trix-editor>` elements with the appropriate
    `aria-label` attribute, also support locating elements that match the
    corresponding `<label>` element's text.

    *Sean Doyle*

*   Be able to add a default value to `rich_text_area`.

    ```ruby
    form.rich_text_area :content, value: "<h1>Hello world</h1>"
    #=> <input type="hidden" name="message[content]" id="message_content_trix_input_message_1" value="<h1>Hello world</h1>">
    ```

    *Paulo Ancheta*

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
