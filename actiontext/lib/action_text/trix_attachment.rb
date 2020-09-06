# frozen_string_literal: true

module ActionText
  class TrixAttachment
    TAG_NAME = 'figure'
    SELECTOR = '[data-trix-attachment]'

    COMPOSED_ATTRIBUTES = %w( caption presentation )
    ATTRIBUTES = %w( sgid contentType url href filename filesize width height previewable content ) + COMPOSED_ATTRIBUTES
    ATTRIBUTE_TYPES = {
      'previewable' => ->(value) { value.to_s == 'true' },
      'filesize'    => ->(value) { Integer(value.to_s) rescue value },
      'width'       => ->(value) { Integer(value.to_s) rescue nil },
      'height'      => ->(value) { Integer(value.to_s) rescue nil },
      :default      => ->(value) { value.to_s }
    }

    class << self
      def from_attributes(attributes)
        attributes = process_attributes(attributes)

        trix_attachment_attributes = attributes.except(*COMPOSED_ATTRIBUTES)
        trix_attributes = attributes.slice(*COMPOSED_ATTRIBUTES)

        node = ActionText::HtmlConversion.create_element(TAG_NAME)
        node['data-trix-attachment'] = JSON.generate(trix_attachment_attributes)
        node['data-trix-attributes'] = JSON.generate(trix_attributes) if trix_attributes.any?

        new(node)
      end

      private
        def process_attributes(attributes)
          typecast_attribute_values(transform_attribute_keys(attributes))
        end

        def transform_attribute_keys(attributes)
          attributes.transform_keys { |key| key.to_s.underscore.camelize(:lower) }
        end

        def typecast_attribute_values(attributes)
          attributes.map do |key, value|
            typecast = ATTRIBUTE_TYPES[key] || ATTRIBUTE_TYPES[:default]
            [key, typecast.call(value)]
          end.to_h
        end
    end

    attr_reader :node

    def initialize(node)
      @node = node
    end

    def attributes
      @attributes ||= attachment_attributes.merge(composed_attributes).slice(*ATTRIBUTES)
    end

    def to_html
      ActionText::HtmlConversion.node_to_html(node)
    end

    def to_s
      to_html
    end

    private
      def attachment_attributes
        read_json_object_attribute('data-trix-attachment')
      end

      def composed_attributes
        read_json_object_attribute('data-trix-attributes')
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
  end
end
