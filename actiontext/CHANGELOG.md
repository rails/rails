*   Apply `field_error_proc` to `rich_text_area` form fields.

    *Kaíque Kandy Koga*

*   Action Text attachment URLs rendered in a background job (a la Turbo
    Streams) now use `Rails.application.default_url_options` and
    `Rails.application.config.force_ssl` instead of `http://example.org`.

    *Jonathan Hefner*

*   Support `strict_loading:` option for `has_rich_text` declaration

    *Sean Doyle*

*   Update ContentAttachment so that it can encapsulate arbitrary HTML content in a document.

    *Jamis Buck*

*   Fix an issue that caused the content layout to render multiple times when a
    rich_text field was updated.

    *Jacob Herrington*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actiontext/CHANGELOG.md) for previous changes.
