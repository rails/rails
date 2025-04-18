# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class BoundSqlLiteral < NodeExpression
      attr_reader :sql_with_placeholders, :positional_binds, :named_binds

      def initialize(sql_with_placeholders, positional_binds, named_binds)
        has_positional = !(positional_binds.nil? || positional_binds.empty?)
        has_named = !(named_binds.nil? || named_binds.empty?)

        if has_positional
          if has_named
            raise BindError.new("cannot mix positional and named binds", sql_with_placeholders)
          end
          if positional_binds.size != (expected = sql_with_placeholders.count("?"))
            raise BindError.new("wrong number of bind variables (#{positional_binds.size} for #{expected})", sql_with_placeholders)
          end
        elsif has_named
          tokens_in_string = sql_with_placeholders.scan(/:(?<!::)([a-zA-Z]\w*)/).flatten.map(&:to_sym).uniq
          tokens_in_hash = named_binds.keys.map(&:to_sym).uniq

          if !(missing = (tokens_in_string - tokens_in_hash)).empty?
            if missing.size == 1
              raise BindError.new("missing value for #{missing.first.inspect}", sql_with_placeholders)
            else
              raise BindError.new("missing values for #{missing.inspect}", sql_with_placeholders)
            end
          end
        end

        @sql_with_placeholders = sql_with_placeholders
        if has_positional
          @positional_binds = positional_binds
          @named_binds = nil
        else
          @positional_binds = nil
          @named_binds = named_binds
        end
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

      def +(other)
        raise ArgumentError, "Expected Arel node" unless Arel.arel_node?(other)

        Fragments.new([self, other])
      end

      def inspect
        "#<#{self.class.name} #{sql_with_placeholders.inspect} #{(named_binds || positional_binds).inspect}>"
      end
    end
  end
end
