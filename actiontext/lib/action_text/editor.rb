# frozen_string_literal: true

module ActionText
  class Editor # :nodoc:
    extend ActiveSupport::Autoload
    include ActiveSupport::Configurable

    autoload :Configurator

    attr_reader :name

    def initialize(name, options = {})
      @name = name
      config.merge!(options)
    end

    def rich_text_area_tag(view_context, name, value = nil, options = {})
      raise NotImplementedError, "#rich_text_area_tag"
    end

    def fill_in_rich_text_area(page, locator = nil, with:)
      raise NotImplementedError, "#fill_in_rich_text_area"
    end

    def canonicalize_fragment(fragment)
      fragment = fragment_by_canonicalizing_attachments(fragment)
      fragment = AttachmentGallery.fragment_by_canonicalizing_attachment_galleries(fragment)
      fragment
    end

    def fragment_by_canonicalizing_attachments(content)
      fragment_by_minifying_attachments(fragment_by_converting_attachments(content))
    end

    def fragment_by_minifying_attachments(content)
      Fragment.wrap(content).replace(Attachment.tag_name) do |node|
        node.tap { |n| n.inner_html = "" }
      end
    end

    def fragment_by_converting_attachments(content)
      Fragment.wrap(content).replace(attachment_selector) do |node|
        editor_attachment = EditorAttachment.new(node, prefix: attachment_prefix)

        Attachment.from_attributes(editor_attachment.attributes)
      end
    end

    def attachment_from_attributes(attributes)
      node = HtmlConversion.create_element(attachment_tag_name)

      EditorAttachment.new(node, prefix: attachment_prefix).from_attributes(attributes)
    end

    def links(fragment)
      fragment.find_all("a[href]").map { |a| a["href"] }.uniq
    end

    def attachments(fragment)
      attachment_nodes(fragment).map do |node|
        attachment_for_node(node)
      end
    end

    def attachment_galleries(fragment)
      attachment_gallery_nodes(fragment).map do |node|
        attachment_gallery_for_node(node)
      end
    end

    def attachables(fragment)
      attachment_nodes(fragment).map do |node|
        Attachable.from_node(node)
      end
    end

    def render_attachments(fragment, **options, &block)
      fragment.replace(Attachment.tag_name) do |node|
        block.call(attachment_for_node(node, **options))
      end
    end

    def render_attachment_galleries(fragment, &block)
      AttachmentGallery.fragment_by_replacing_attachment_gallery_nodes(fragment) do |node|
        block.call(attachment_gallery_for_node(node))
      end
    end

    def to_plain_text(content)
      content&.to_plain_text.to_s
    end

    def to_html(content)
      if (fragment = content&.fragment)
        render_attachments(fragment) { |attachment| attachment.to_editor_attachment(name) }.to_html
      end
    end

    private
      def attachment_nodes(fragment)
        fragment.find_all(Attachment.tag_name)
      end

      def attachment_for_node(node, with_full_attributes: true)
        attachment = Attachment.from_node(node)
        with_full_attributes ? attachment.with_full_attributes : attachment
      end

      def attachment_gallery_nodes(fragment)
        AttachmentGallery.find_attachment_gallery_nodes(fragment)
      end

      def attachment_gallery_for_node(node)
        AttachmentGallery.from_node(node)
      end

      def attachment_prefix
        config.attachments[:prefix]
      end

      def attachment_selector
        "[data-#{attachment_prefix}-attachment]"
      end

      def attachment_tag_name
        config.attachments[:tag_name]
      end
  end
end
