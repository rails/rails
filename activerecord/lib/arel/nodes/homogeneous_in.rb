# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class HomogeneousIn < Node
      attr_reader :attribute, :values, :type

      def initialize(values, attribute, type)
        @values = values
        @attribute = attribute
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
        Arel::Nodes::HomogeneousIn.new(values, attribute, type == :in ? :notin : :in)
      end

      def left
        attribute
      end

      def right
        attribute.quoted_array(values)
      end

      def casted_values
        type = attribute.type_caster

        casted_values = values.map do |raw_value|
          type.serialize(raw_value) if type.serializable?(raw_value)
        end

        casted_values.compact!
        casted_values
      end

      def proc_for_binds
        -> value { ActiveModel::Attribute.with_cast_value(attribute.name, value, attribute.type_caster) }
      end

      def fetch_attribute(&block)
        if attribute
          yield attribute
        else
          expr.fetch_attribute(&block)
        end
      end

      protected
        def ivars
          [@attribute, @values, @type]
        end
    end
  end
end
