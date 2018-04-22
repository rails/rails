# frozen_string_literal: true

module ActiveRecord
  class Relation
    module RelationValues
      EMPTY_FROM_CLAUSE = FromClause.empty
      EMPTY_WHERE_CLAUSE = WhereClause.empty

      FROZEN_EMPTY_ARRAY = [].freeze
      FROZEN_EMPTY_HASH = {}.freeze

      VALUES =
        {}.tap do |values|
          MULTI_VALUE_METHODS.each { |value| values[value] = :"#{value}_values" }
          SINGLE_VALUE_METHODS.each { |value| values[value] = :"#{value}_value" }
          CLAUSE_METHODS.each { |value| values[value] = :"#{value}_clause" }
        end.freeze

      def self.included(base)
        base.attr_reader *(SINGLE_VALUE_METHODS - %i[create_with]).map { |value| :"#{value}_value" }
        base.alias_method :extensions, :extending_values
      end

      def empty_scope?
        VALUES.each_value.all? { |value| !instance_variable_defined?(value) }
      end

      def values
        VALUES.each_with_object({}) do |(key, value), new_values|
          next unless instance_variable_defined?(value)
          new_values[key] = public_send(value)
        end
      end

      def create_with_value
        @create_with_value || FROZEN_EMPTY_HASH
      end

      def where_clause
        @where_clause || EMPTY_WHERE_CLAUSE
      end

      def having_clause
        @having_clause || EMPTY_WHERE_CLAUSE
      end

      def from_clause
        @from_clause || EMPTY_FROM_CLAUSE
      end

      MULTI_VALUE_METHODS.each do |value|
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{value}_values
            @#{value}_values || FROZEN_EMPTY_ARRAY
          end
        CODE
      end

      VALUES.each_value do |value|
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{value}=(value)
            assert_mutability!
            @#{value} = value
          end
        CODE
      end

      private

      def initialize_values_from(values)
        values.each do |key, value|
          public_send(:"#{VALUES[key]}=", value)
        end
      end
    end
  end
end
