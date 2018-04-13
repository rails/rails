module ActionText
  module Attachables
    class RemoteImage
      extend ActiveModel::Naming

      class << self
        def from_node(node)
          if node["url"] && content_type_is_image?(node["content-type"])
            new(attributes_from_node(node))
          end
        end

        private
          def content_type_is_image?(content_type)
            content_type.to_s =~ /^image(\/.+|$)/
          end

          def attributes_from_node(node)
            { url: node["url"],
              content_type: node["content-type"],
              width: node["width"],
              height: node["height"] }
          end
      end

      attr_reader :url, :content_type, :width, :height

      def initialize(attributes = {})
        @url = attributes[:url]
        @content_type = attributes[:content_type]
        @width = attributes[:width]
        @height = attributes[:height]
      end

      def attachable_plain_text_representation(caption)
        "[#{caption || "Image"}]"
      end

      def to_partial_path
        "action_text/attachables/remote_image"
      end
    end
  end
end
