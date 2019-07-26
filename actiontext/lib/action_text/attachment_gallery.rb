# frozen_string_literal: true

module ActionText
  class AttachmentGallery
    include ActiveModel::Model

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
        Fragment.wrap(content).find_all(SELECTOR).select do |node|
          node.children.all? do |child|
            if child.text?
              child.text =~ /\A(\n|\ )*\z/
            else
              child.matches? ATTACHMENT_SELECTOR
            end
          end
        end
      end

      def from_node(node)
        new(node)
      end
    end

    attr_reader :node

    def initialize(node)
      @node = node
    end

    def attachments
      @attachments ||= node.css(ATTACHMENT_SELECTOR).map do |node|
        ActionText::Attachment.from_node(node).with_full_attributes
      end
    end

    def size
      attachments.size
    end

    def inspect
      "#<#{self.class.name} size=#{size.inspect}>"
    end

    TAG_NAME = "div"
    ATTACHMENT_SELECTOR = "#{ActionText::Attachment::SELECTOR}[presentation=gallery]"
    SELECTOR = "#{TAG_NAME}:has(#{ATTACHMENT_SELECTOR} + #{ATTACHMENT_SELECTOR})"

    private_constant :TAG_NAME, :ATTACHMENT_SELECTOR, :SELECTOR
  end
end
