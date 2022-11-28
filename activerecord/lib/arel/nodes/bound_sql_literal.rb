# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class BoundSqlLiteral < NodeExpression
      attr_reader :sql_with_placeholders, :positional_binds, :named_binds

      def initialize(sql_with_placeholders, positional_binds, named_binds)
        @sql_with_placeholders = sql_with_placeholders
        @positional_binds = positional_binds
        @named_binds = named_binds
      end

      def hash
        [self.class, sql_with_placeholders, positional_binds, named_binds].hash
      end

      def eql?(other)
        self.class == other.class &&
          sql_with_placeholders == other.sql_with_placeholders &&
          positional_binds == other.positional_binds &&
          named_binds == other.named_binds
      end
      alias :== :eql?

      def inspect
        "#<#{self.class.name} #{sql_with_placeholders.inspect} #{positional_binds.inspect} #{named_binds.inspect}>"
      end

      def ast
        self
      end
    end
  end
end
