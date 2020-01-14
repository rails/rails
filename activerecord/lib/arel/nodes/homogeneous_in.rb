# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class HomogeneousIn < Node
      attr_reader :attribute, :quoted_column_name, :values, :type

      def initialize(quoted_column_name, values, attribute, type)
        @quoted_column_name = quoted_column_name
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
        true
      end

      def invert
        Arel::Nodes::HomogeneousIn.new(quoted_column_name, values, attribute, type == :in ? :notin : :in)
      end

      def left
        attribute
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
          [@attribute, @quoted_column_name, @values, @type]
        end
    end
  end
end
