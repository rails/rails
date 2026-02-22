*   Add `to_markdown` to Action Text, mirroring `to_plain_text`.

    Converts rich text content to Markdown, supporting headings, bold, italic,
    strikethrough, inline code, code blocks, blockquotes, ordered and unordered
    lists, links, tables, and attachments. Custom attachment representations can be
    provided by implementing `attachable_markdown_representation` on the
    attachable model.

        message = Message.create!(content: "<h1>Hello</h1><p>This is <strong>bold</strong></p>")
        message.content.to_markdown # => "# Hello\n\nThis is **bold**"

    *Mike Dalessio*

*   Make `ActionText::Attachable#read_attribute_for_serialization` public.

    *Sally Hall*

*   Install generator now detects which JS package manager to use when
    installing javascript dependencies for the editor.

    *David Lowenfels*

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
