## Rails 8.1.2 (January 08, 2026) ##

*   No changes.


## Rails 8.1.1 (October 28, 2025) ##

*   No changes.


## Rails 8.1.0 (October 22, 2025) ##

*   De-couple `@rails/actiontext/attachment_upload.js` from `Trix.Attachment`

    Implement `@rails/actiontext/index.js` with a `direct-upload:progress` event
    listeners and `Promise` resolution.

    *Sean Doyle*

*   Capture block content for form helper methods

    ```erb
    <%= rich_textarea_tag :content, nil do %>
      <h1>hello world</h1>
    <% end %>
    <!-- <input type="hidden" name="content" id="trix_input_1" value="&lt;h1&gt;hello world&lt;/h1&gt;"/><trix-editor … -->

    <%= rich_textarea :message, :content, input: "trix_input_1" do %>
      <h1>hello world</h1>
    <% end %>
    <!-- <input type="hidden" name="message[content]" id="trix_input_1" value="&lt;h1&gt;hello world&lt;/h1&gt;"/><trix-editor … -->

    <%= form_with model: Message.new do |form| %>
      <%= form.rich_textarea :content do %>
        <h1>hello world</h1>
      <% end %>
    <% end %>
    <!-- <form action="/messages" accept-charset="UTF-8" method="post"><input type="hidden" name="message[content]" id="message_content_trix_input_message" value="&lt;h1&gt;hello world&lt;/h1&gt;"/><trix-editor … -->
    ```

    *Sean Doyle*

*   Generalize `:rich_text_area` Capybara selector

    Prepare for more Action Text-capable WYSIWYG editors by making
    `:rich_text_area` rely on the presence of `[role="textbox"]` and
    `[contenteditable]` HTML attributes rather than a `<trix-editor>` element.

    *Sean Doyle*

*   Forward `fill_in_rich_text_area` options to Capybara

    ```ruby
    fill_in_rich_textarea "Rich text editor", id: "trix_editor_1", with: "Hello world!"
    ```

    *Sean Doyle*

*   Attachment upload progress accounts for server processing time.

    *Jeremy Daer*

*   The Trix dependency is now satisfied by a gem, `action_text-trix`, rather than vendored
    files. This allows applications to bump Trix versions independently of Rails
    releases. Effectively this also upgrades Trix to `>= 2.1.15`.

    *Mike Dalessio*

*   Change `ActionText::RichText#embeds` assignment from `before_save` to `before_validation`

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actiontext/CHANGELOG.md) for previous changes.
