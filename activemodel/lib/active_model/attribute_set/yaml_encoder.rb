# frozen_string_literal: true

module ActiveModel
  class AttributeSet
    # Attempts to do more intelligent YAML dumping of an
    # ActiveModel::AttributeSet to reduce the size of the resulting string
    module YAMLEncoder # :nodoc:
      extend self

      def encode(attribute_set, coder, default_types)
        coder["concise_attributes"] = attribute_set.each_value.map do |attr|
          if attr.type.equal?(default_types[attr.name])
            attr.with_type(nil)
          else
            attr
          end
        end
      end

      def decode(coder, default_types, store_attribute_definitions = {})
        if coder["attributes"]
          coder["attributes"]
        else
          attributes_hash = AttributeHash.new(store_attribute_definitions)
          coder["concise_attributes"].each do |attr|
            attr = attr.with_type(default_types[attr.name]) if attr.type.nil?
            attributes_hash[attr.name] = attr
          end
          AttributeSet.new(attributes_hash)
        end
      end
    end
  end
end
