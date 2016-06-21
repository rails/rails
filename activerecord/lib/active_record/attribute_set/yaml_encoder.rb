module ActiveRecord
  class AttributeSet
    # Attempts to do more intelligent YAML dumping of an
    # ActiveRecord::AttributeSet to reduce the size of the resulting string
    class YAMLEncoder
      def initialize(default_types)
        @default_types = default_types
      end

      # Populate +coder+ with 'concise_attributes' using +attribute_set+.
      #
      # If any attribute's name matches a +default_types+ key, then the
      # attribute will be cast by passing +nil+ to
      # ActiveRecord::Attribute#with_type.
      def encode(attribute_set, coder)
        coder['concise_attributes'] = attribute_set.each_value.map do |attr|
          if attr.type.equal?(default_types[attr.name])
            attr.with_type(nil)
          else
            attr
          end
        end
      end

      # Decode a previously encoded +coder+.
      #
      # +coder+ should be the result of previously encoding an Active Record
      # model, using #encode.
      #
      # If +coder+ contains an 'attributes' key, then #decode returns the value
      # under the 'attributes' key.
      #
      # Otherwise, #decode will build an attributes hash from the provided coder,
      # using its value under 'concise_attributes', while casting any nil types
      # using default_types. The resulting hash is used to return a new
      # ActiveRecord::AttributeSet.
      def decode(coder)
        if coder['attributes']
          coder['attributes']
        else
          attributes_hash = Hash[coder['concise_attributes'].map do |attr|
            if attr.type.nil?
              attr = attr.with_type(default_types[attr.name])
            end
            [attr.name, attr]
          end]
          AttributeSet.new(attributes_hash)
        end
      end

      protected

      attr_reader :default_types
    end
  end
end
