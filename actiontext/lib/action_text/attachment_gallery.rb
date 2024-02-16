# frozen_string_literal: true

# :markup: markdown

module ActionText
  class AttachmentGallery
    include ActiveModel::Model

    TAG_NAME = "div"
    private_constant :TAG_NAME

    class << self
      def fragment_by_canonicalizing_attachment_galleries(content)
        fragment_by_replacing_attachment_gallery_nodes(content) do |node|
          "<#{TAG_NAME}>#{node.inner_html}</#{TAG_NAME}>"
        end
      end

      def fragment_by_replacing_attachment_gallery_nodes(content)
        Fragment.wrap(content).update do |source|
          find_attachment_gallery_nodes(source).each do |node|
            node.replace(yield(node).to_s)
          end
        end
      end

      def find_attachment_gallery_nodes(content)
        Fragment.wrap(content).find_all(selector).select do |node|
          node.children.all? do |child|
            if child.text?
              /\A(\n|\ )*\z/.match?(child.text)
            else
              child.matches? attachment_selector
            end
          end
        end
      end

      def from_node(node)
        new(node)
      end

      def attachment_selector
        "#{ActionText::Attachment.tag_name}[presentation=gallery]"
      end

      def selector
        "#{TAG_NAME}:has(#{attachment_selector} + #{attachment_selector})"
      end
    end

    attr_reader :node

    def initialize(node)
      @node = node
    end

    def attachments
      @attachments ||= node.css(ActionText::AttachmentGallery.attachment_selector).map do |node|
        ActionText::Attachment.from_node(node).with_full_attributes
      end
    end

    def size
      attachments.size
    end

    def inspect
      "#<#{self.class.name} size=#{size.inspect}>"
    end
  end
end
