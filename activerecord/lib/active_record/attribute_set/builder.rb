module ActiveRecord
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      attr_reader :types

      def initialize(types)
        @types = types
      end

      def build_from_database(values = {}, additional_types = {})
        attributes = build_attributes_from_values(values, additional_types)
        add_uninitialized_attributes(attributes)
        AttributeSet.new(attributes)
      end

      private

      def build_attributes_from_values(values, additional_types)
        values.each_with_object({}) do |(name, value), hash|
          type = additional_types.fetch(name, types[name])
          hash[name] = Attribute.from_database(name, value, type)
        end
      end

      def add_uninitialized_attributes(attributes)
        types.each_key do |name|
          next if attributes.key? name
          type = types[name]
          attributes[name] =
            Attribute.uninitialized(name, type)
        end
      end
    end
  end
end
