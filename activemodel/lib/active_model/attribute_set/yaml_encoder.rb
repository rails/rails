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

      def decode(coder, default_types)
        if coder["attributes"]
          coder["attributes"]
        else
          attributes_hash = Hash[coder["concise_attributes"].map do |attr|
            if attr.type.nil?
              attr = attr.with_type(default_types[attr.name])
            end
            [attr.name, attr]
          end]
          AttributeSet.new(attributes_hash)
        end
      end
    end
  end
end
