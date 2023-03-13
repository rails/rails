## Rails 6.1.7.3 (March 13, 2023) ##

*   No changes.


## Rails 6.1.7.2 (January 24, 2023) ##

*   No changes.


## Rails 6.1.7.1 (January 17, 2023) ##

*   No changes.


## Rails 6.1.7 (September 09, 2022) ##

*   No changes.


## Rails 6.1.6.1 (July 12, 2022) ##

*   No changes.


## Rails 6.1.6 (May 09, 2022) ##

*   No changes.


## Rails 6.1.5.1 (April 26, 2022) ##

*   No changes.


## Rails 6.1.5 (March 09, 2022) ##

*   Fix Action Text extra trix content wrapper.

    *Alexandre Ruban*


## Rails 6.1.4.7 (March 08, 2022) ##

*   No changes.


## Rails 6.1.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.1.4.3 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.1.4 (June 24, 2021) ##

*   Always render attachment partials as HTML with `:html` format inside trix editor.

    *James Brooks*


## Rails 6.1.3.2 (May 05, 2021) ##

*   No changes.


## Rails 6.1.3.1 (March 26, 2021) ##

*   No changes.


## Rails 6.1.3 (February 17, 2021) ##

*   No changes.


## Rails 6.1.2.1 (February 10, 2021) ##

*   No changes.


## Rails 6.1.2 (February 09, 2021) ##

*   No changes.


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
