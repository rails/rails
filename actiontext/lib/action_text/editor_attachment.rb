# frozen_string_literal: true

# :markup: markdown

module ActionText
  class EditorAttachment # :nodoc:
    COMPOSED_ATTRIBUTES = %w( caption presentation )
    ATTRIBUTES = %w( sgid contentType url href filename filesize width height previewable content ) + COMPOSED_ATTRIBUTES
    ATTRIBUTE_TYPES = {
      "previewable" => ->(value) { value.to_s == "true" },
      "filesize"    => ->(value) { Integer(value.to_s, exception: false) || value },
      "width"       => ->(value) { Integer(value.to_s, exception: false) },
      "height"      => ->(value) { Integer(value.to_s, exception: false) },
      :default      => ->(value) { value.to_s }
    }
    private_constant :ATTRIBUTES, :ATTRIBUTE_TYPES, :COMPOSED_ATTRIBUTES

    attr_reader :node

    def initialize(node, prefix:)
      @node = node
      @attachment_name = "data-#{prefix}-attachment"
      @composed_name = "data-#{prefix}-attributes"
    end

    def attributes
      @attributes ||= attachment_attributes.merge(composed_attributes).slice(*ATTRIBUTES)
    end

    def from_attributes(attributes)
      attributes = process_attributes(attributes)

      attachment_attributes = attributes.except(*COMPOSED_ATTRIBUTES)
      composed_attributes = attributes.slice(*COMPOSED_ATTRIBUTES)

      node[attachment_name] = JSON.generate(attachment_attributes)
      node[composed_name] = JSON.generate(composed_attributes) if composed_attributes.any?
      self
    end

    def to_html
      ActionText::HtmlConversion.node_to_html(node)
    end

    def to_s
      to_html
    end

    private
      attr_reader :attachment_name, :composed_name

      def attachment_attributes
        read_json_object_attribute(attachment_name)
      end

      def composed_attributes
        read_json_object_attribute(composed_name)
      end

      def read_json_object_attribute(name)
        read_json_attribute(name) || {}
      end

      def read_json_attribute(name)
        if value = node[name]
          begin
            JSON.parse(value)
          rescue => e
            Rails.logger.error "[#{self.class.name}] Couldn't parse JSON #{value} from NODE #{node.inspect}"
            Rails.logger.error "[#{self.class.name}] Failed with #{e.class}: #{e.backtrace}"
            nil
          end
        end
      end

      def process_attributes(attributes)
        typecast_attribute_values(transform_attribute_keys(attributes))
      end

      def transform_attribute_keys(attributes)
        attributes.transform_keys { |key| key.to_s.underscore.camelize(:lower) }
      end

      def typecast_attribute_values(attributes)
        attributes.to_h do |key, value|
          typecast = ATTRIBUTE_TYPES[key] || ATTRIBUTE_TYPES[:default]
          [key, typecast.call(value)]
        end
      end
  end
end
