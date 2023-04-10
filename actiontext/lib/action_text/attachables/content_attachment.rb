# frozen_string_literal: true

module ActionText
  module Attachables
    class ContentAttachment # :nodoc:
      include ActiveModel::Model

      def self.from_node(node)
        attachment = new(content_type: node["content-type"], content: node["content"])
        attachment if attachment.valid?
      end

      attr_accessor :content_type, :content

      validates_format_of :content_type, with: /html/
      validates_presence_of :content

      def attachable_plain_text_representation(caption)
        content_instance.fragment.source
      end

      def to_html
        @to_html ||= content_instance.render(content_instance)
      end

      def to_s
        to_html
      end

      def to_partial_path
        "action_text/attachables/content_attachment"
      end

      private
        def content_instance
          @content_instance ||= ActionText::Content.new(content)
        end
    end
  end
end
