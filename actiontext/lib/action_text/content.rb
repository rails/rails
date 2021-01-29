# frozen_string_literal: true

module ActionText
  class Content
    include Rendering, Serialization

    attr_reader :fragment

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

    def links
      @links ||= fragment.find_all("a[href]").map { |a| a["href"] }.uniq
    end

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
      content = fragment.replace(ActionText::Attachment::SELECTOR) do |node|
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

    def to_s
      to_rendered_html_with_layout
    end

    def as_json(*)
      to_html
    end

    def inspect
      "#<#{self.class.name} #{to_s.truncate(25).inspect}>"
    end

    def ==(other)
      if other.is_a?(self.class)
        to_s == other.to_s
      end
    end

    private
      def attachment_nodes
        @attachment_nodes ||= fragment.find_all(ActionText::Attachment::SELECTOR)
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
