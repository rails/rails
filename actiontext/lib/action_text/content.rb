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
    include Rendering, Serialization, ContentHelper

    attr_reader :fragment

    delegate :deconstruct, to: :fragment
    delegate :blank?, :empty?, :html_safe, :present?, to: :to_html # Delegating to to_html to avoid including the layout

    class << self
      def fragment_by_canonicalizing_content(content)
        fragment = ActionText::Attachment.fragment_by_canonicalizing_attachments(content)
        fragment = ActionText::AttachmentGallery.fragment_by_canonicalizing_attachment_galleries(fragment)
        fragment
      end
    end

    def initialize(content = nil, options = {})
      options.with_defaults! canonicalize: true

      if options[:canonicalize]
        @fragment = self.class.fragment_by_canonicalizing_content(content)
      else
        @fragment = ActionText::Fragment.wrap(content)
      end
    end

    # Extracts links from the HTML fragment:
    #
    #     html = '<a href="http://example.com/">Example</a>'
    #     content = ActionText::Content.new(html)
    #     content.links # => ["http://example.com/"]
    def links
      @links ||= fragment.find_all("a[href]").map { |a| a["href"] }.uniq
    end

    # Extracts +ActionText::Attachment+s from the HTML fragment:
    #
    #     attachable = ActiveStorage::Blob.first
    #     html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}" caption="Captioned"></action-text-attachment>)
    #     content = ActionText::Content.new(html)
    #     content.attachments # => [#<ActionText::Attachment attachable=#<ActiveStorage::Blob...
    def attachments
      @attachments ||= attachment_nodes.map do |node|
        attachment_for_node(node)
      end
    end

    def attachment_galleries
      @attachment_galleries ||= attachment_gallery_nodes.map do |node|
        attachment_gallery_for_node(node)
      end
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
      @attachables ||= attachment_nodes.map do |node|
        ActionText::Attachable.from_node(node)
      end
    end

    def append_attachables(attachables)
      attachments = ActionText::Attachment.from_attachables(attachables)
      self.class.new([self.to_s.presence, *attachments].compact.join("\n"))
    end

    def render_attachments(**options, &block)
      content = fragment.replace(ActionText::Attachment.tag_name) do |node|
        if node.key?("content")
          sanitized_content = sanitize_content_attachment(node.remove_attribute("content").to_s)
          node["content"] = sanitized_content if sanitized_content.present?
        end
        block.call(attachment_for_node(node, **options))
      end
      self.class.new(content, canonicalize: false)
    end

    def render_attachment_galleries(&block)
      content = ActionText::AttachmentGallery.fragment_by_replacing_attachment_gallery_nodes(fragment) do |node|
        block.call(attachment_gallery_for_node(node))
      end
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
    # browsers without additional sanitization.
    #
    #     content = ActionText::Content.new("&lt;script&gt;alert()&lt;/script&gt;")
    #     content.to_plain_text # => "<script>alert()</script>"
    #     ActionText::ContentHelper.sanitizer.sanitize(content.to_plain_text) # => ""
    def to_plain_text
      render_attachments(with_full_attributes: false, &:to_plain_text).fragment.to_plain_text
    end

    def to_trix_html
      render_attachments(&:to_trix_attachment).to_html
    end

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

    private
      def attachment_nodes
        @attachment_nodes ||= fragment.find_all(ActionText::Attachment.tag_name)
      end

      def attachment_gallery_nodes
        @attachment_gallery_nodes ||= ActionText::AttachmentGallery.find_attachment_gallery_nodes(fragment)
      end

      def attachment_for_node(node, with_full_attributes: true)
        attachment = ActionText::Attachment.from_node(node)
        with_full_attributes ? attachment.with_full_attributes : attachment
      end

      def attachment_gallery_for_node(node)
        ActionText::AttachmentGallery.from_node(node)
      end
  end
end

ActiveSupport.run_load_hooks :action_text_content, ActionText::Content
