*   Deprecate Trix-specific classes, modules, and methods

    * `ActionText::Attachable#to_trix_content_attachment_partial_path`. Override
      `#to_editor_content_attachment_partial_path` instead.
    * `ActionText::Attachments::TrixConversion`
    * `ActionText::Content#to_trix_html`.
    * `ActionText::RichText#to_trix_html`.
    * `ActionText::TrixAttachment`

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actiontext/CHANGELOG.md) for previous changes.
