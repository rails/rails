# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class RowConstructor < Node
      attr_reader :attributes_set, :values, :type

      def initialize(values, attributes_set, type)
        @values = values
        @attributes_set = attributes_set
        @type = type
      end

      def hash
        ivars.hash
      end

      def eql?(other)
        super || (self.class == other.class && self.ivars == other.ivars)
      end
      alias :== :eql?

      def equality?
        type == :in
      end

      def invert
        Arel::Nodes::RowConstructor.new(values, attributes_set, type == :in ? :notin : :in)
      end

      def table_name
        attributes_set.relation.table_alias || attributes_set.relation.name
      end

      def column_names
        attributes_set.names
      end

      def casted_values
        named_values = values.map { |values_array| attributes_set.names.zip(values_array).to_h }

        named_values.map do |values_hash|
          values_hash.map do |attribute_name, raw_value|
            type = attributes_set.type_caster_by_name[attribute_name]
            type.serialize(raw_value)
          end
        end
      end

      protected
        def ivars
          [@attributes_set, @values, @type]
        end
    end
  end
end
