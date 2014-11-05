module ActiveRecord
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      attr_reader :types

      def initialize(types)
        @types = types
      end

      def build_from_database(values = {}, additional_types = {})
        build_from_database_pairs(values.keys, values.values, additional_types)
      end

      def build_from_database_pairs(columns, values, additional_types)
        attributes = build_attributes_from_values(columns, values, additional_types)
        add_uninitialized_attributes(attributes)
        AttributeSet.new(attributes)
      end

      private

      def build_attributes_from_values(columns, values, additional_types)
        # We are performing manual iteration here as this method is a performance
        # hotspot
        hash = {}
        index = 0
        length = columns.length

        while index < length
          name = columns[index]
          value = values[index]
          type = additional_types.fetch(name, types[name])
          hash[name] = Attribute.from_database(name, value, type)
          index += 1
        end

        hash
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
