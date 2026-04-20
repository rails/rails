*   Support block children in editor elements alongside value.

    Blocks were introduced in #55827, but only as an alternative to the value
    argument: the block was captured and used as the initial editor content,
    making it either value OR block — not both.

    The block semantics are now changed so that blocks render as DOM children of
    the editor element instead. Value and block are now independent: value flows
    into the editor's content binding (the hidden input for Trix, the value
    attribute for custom editors), while the block renders as inner DOM children
    — useful for embedding custom elements such as prompt menus or toolbar
    extensions.

    This enables other editors like Lexxy to use the block form for configuration
    — injecting child elements into the editor tag — while the rich text value is
    preserved separately.

    Trix preserves the original block-as-initial-value contract by capturing the
    block in `TrixEditor::Tag#render_in` when no value is present, keeping its
    hidden input populated as before.

    *Jorge Manrubia*

*   Render `MissingAttachable` as "☒" in plain text.

    Previously, `Content#to_plain_text` would replace a `MissingAttachable` with a blank string.
    Now it renders the same "☒" character used in the HTML representation.

    *Mike Dalessio*

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
