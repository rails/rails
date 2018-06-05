module ActionText
  class Content
    include Serialization

    attr_reader :fragment

    delegate :blank?, :empty?, :html_safe, :present?, to: :to_s

    def initialize(content = nil)
      @fragment = ActionText::Attachment.fragment_by_canonicalizing_attachments(content)
    end

    def links
      @links ||= fragment.find_all("a[href]").map { |a| a["href"] }.uniq
    end

    def attachments
      @attachments ||= attachment_nodes.map do |node|
        attachment_for_node(node)
      end
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
      fragment.replace(ActionText::Attachment::SELECTOR) do |node|
        block.call(attachment_for_node(node, **options))
      end
    end

    def to_plain_text
      render_attachments(with_full_attributes: false, &:to_plain_text).to_plain_text
    end

    def to_trix_html
      render_attachments(&:to_trix_attachment).to_html
    end

    def to_html
      render_attachments do |attachment|
        attachment.node.tap do |node|
          node.inner_html = ActionText.renderer.render(attachment)
        end
      end.to_html
    end

    def to_s
      "<div class='trix-content'>#{to_html}</div>".html_safe
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

      def attachment_for_node(node, with_full_attributes: true)
        attachment = ActionText::Attachment.from_node(node)
        with_full_attributes ? attachment.with_full_attributes : attachment
      end
  end
end
