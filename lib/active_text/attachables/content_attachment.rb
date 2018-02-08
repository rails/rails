module ActiveText
  module Attachables
    class ContentAttachment
      include ActiveModel::Model

      def self.from_node(node)
        if node["content-type"]
          if matches = node["content-type"].match(/vnd\.rubyonrails\.(.+)\.html/)
            attachment = new(name: matches[1])
            attachment if attachment.valid?
          end
        end
      end

      attr_accessor :name
      validates_inclusion_of :name, in: %w( horizontal-rule )

      def attachable_plain_text_representation(caption)
        case name
        when "horizontal-rule"
          " ┄ "
        else
          " "
        end
      end

      def to_partial_path
        "active_text/attachables/content_attachment"
      end

      def to_trix_content_attachment_partial_path
        "active_text/attachables/content_attachments/#{name.underscore}"
      end
    end
  end
end
