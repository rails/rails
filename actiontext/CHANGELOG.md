*   Generalize `:rich_text_area` Capybara selector

    Prepare for more Action Text-capable WYSIWYG editors by making
    `:rich_text_area` rely on the presence of `[role="textbox"]` and
    `[contenteditable]` HTML attributes rather than a `<trix-editor>` element.

    *Sean Doyle*

## Rails 8.1.0.beta1 (September 04, 2025) ##

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
