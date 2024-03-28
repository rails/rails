# frozen_string_literal: true

# :markup: markdown

module ActionText
  # # Action Text Content
  #
  # The `ActionText::Content` class wraps an HTML fragment to add support for
  # parsing, rendering and serialization. It can be used to extract links and
  # attachments, convert the fragment to plain text, or serialize the fragment to
  # the database.
  #
  # The ActionText::RichText record serializes the `body` attribute as
  # `ActionText::Content`.
  #
  #     class Message < ActiveRecord::Base
  #       has_rich_text :content
  #     end
  #
  #     message = Message.create!(content: "<h1>Funny times!</h1>")
  #     body = message.content.body # => #<ActionText::Content "<div class=\"trix-conte...">
  #     body.to_s # => "<h1>Funny times!</h1>"
  #     body.to_plain_text # => "Funny times!"
  class Content
    include Rendering, Serialization

    attr_reader :fragment, :editor

    delegate :deconstruct, to: :fragment
    delegate :blank?, :empty?, :html_safe, :present?, to: :to_html # Delegating to to_html to avoid including the layout

    class << self
      def fragment_by_canonicalizing_content(content)
        content = new(content, canonicalize: true, editor: RichText.editors.fetch(:trix))
        content.fragment
      end
      deprecate :fragment_by_canonicalizing_content, deprecator: ActionText.deprecator
    end

    def initialize(content = nil, options = {})
      options.with_defaults! canonicalize: true, editor: RichText.editor

      @fragment = ActionText::Fragment.wrap(content)
      @editor = options[:editor]

      if options[:canonicalize]
        @fragment = editor.canonicalize_fragment(@fragment)
      end
    end

    # Extracts links from the HTML fragment:
    #
    #     html = '<a href="http://example.com/">Example</a>'
    #     content = ActionText::Content.new(html)
    #     content.links # => ["http://example.com/"]
    def links
      @links ||= editor.links(fragment)
    end

    # Extracts +ActionText::Attachment+s from the HTML fragment:
    #
    #     attachable = ActiveStorage::Blob.first
    #     html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}" caption="Captioned"></action-text-attachment>)
    #     content = ActionText::Content.new(html)
    #     content.attachments # => [#<ActionText::Attachment attachable=#<ActiveStorage::Blob...
    def attachments
      @attachments ||= editor.attachments(fragment)
    end

    def attachment_galleries
      @attachment_galleries ||= editor.attachment_galleries(fragment)
    end

    def gallery_attachments
      @gallery_attachments ||= attachment_galleries.flat_map(&:attachments)
    end

    # Extracts +ActionText::Attachable+s from the HTML fragment:
    #
    #     attachable = ActiveStorage::Blob.first
    #     html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}" caption="Captioned"></action-text-attachment>)
    #     content = ActionText::Content.new(html)
    #     content.attachables # => [attachable]
    def attachables
      @attachables ||= editor.attachables(fragment)
    end

    def append_attachables(attachables)
      attachments = ActionText::Attachment.from_attachables(attachables)
      self.class.new([self.to_s.presence, *attachments].compact.join("\n"))
    end

    def render_attachments(**options, &block)
      content = editor.render_attachments(fragment, **options, &block)
      self.class.new(content, canonicalize: false)
    end

    def render_attachment_galleries(&block)
      content = editor.render_attachment_galleries(fragment, &block)
      self.class.new(content, canonicalize: false)
    end

    # Returns a plain-text version of the markup contained by the content, with tags
    # removed but HTML entities encoded.
    #
    #     content = ActionText::Content.new("<h1>Funny times!</h1>")
    #     content.to_plain_text # => "Funny times!"
    #
    #     content = ActionText::Content.new("<div onclick='action()'>safe<script>unsafe</script></div>")
    #     content.to_plain_text # => "safeunsafe"
    #
    # NOTE: that the returned string is not HTML safe and should not be rendered in
    # browsers.
    #
    #     content = ActionText::Content.new("&lt;script&gt;alert()&lt;/script&gt;")
    #     content.to_plain_text # => "<script>alert()</script>"
    def to_plain_text
      render_attachments(with_full_attributes: false, &:to_plain_text).fragment.to_plain_text
    end

    def to_trix_html
      RichText.editors.fetch(:trix).to_html(self)
    end
    deprecate :to_trix_html, deprecator: ActionText.deprecator

    def to_html
      fragment.to_html
    end

    def to_rendered_html_with_layout
      render layout: "action_text/contents/content", partial: to_partial_path, formats: :html, locals: { content: self }
    end

    def to_partial_path
      "action_text/contents/content"
    end

    # Safely transforms Content into an HTML String.
    #
    #     content = ActionText::Content.new(content: "<h1>Funny times!</h1>")
    #     content.to_s # => "<h1>Funny times!</h1>"
    #
    #     content = ActionText::Content.new("<div onclick='action()'>safe<script>unsafe</script></div>")
    #     content.to_s # => "<div>safeunsafe</div>"
    def to_s
      to_rendered_html_with_layout
    end

    def as_json(*)
      to_html
    end

    def inspect
      "#<#{self.class.name} #{to_html.truncate(25).inspect}>"
    end

    def ==(other)
      if self.class == other.class
        to_html == other.to_html
      elsif other.is_a?(self.class)
        to_s == other.to_s
      end
    end
  end
end

ActiveSupport.run_load_hooks :action_text_content, ActionText::Content
