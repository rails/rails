*   Deprecate Trix-specific classes, modules, and methods

    * `ActionText::Attachable#to_trix_content_attachment_partial_path`. Override
      `#to_editor_content_attachment_partial_path` instead.
    * `ActionText::Attachments::TrixConversion`
    * `ActionText::Content#to_trix_html`.
    * `ActionText::RichText#to_trix_html`.
    * `ActionText::TrixAttachment`

    *Sean Doyle*

*   Validate `RemoteImage` URLs at creation time.

    `RemoteImage.from_node` now validates the URL before creating a `RemoteImage` object, using the
    same regex that `AssetUrlHelper` uses during rendering. URLs like "image.png" that would
    previously have been passed to the asset pipeline and raised a `ActionView::Template::Error` are
    rejected early, and gracefully fail by resulting in a `MissingAttachable`.

    *Mike Dalessio*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actiontext/CHANGELOG.md) for previous changes.
