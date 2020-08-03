# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def queries
        [associated_table.join_foreign_key => ids]
      end

      private
        attr_reader :associated_table, :value

        def ids
          case value
          when Relation
            value.select_values.empty? ? value.select(primary_key) : value
          when Array
            value.map { |v| convert_to_id(v) }
          else
            convert_to_id(value)
          end
        end

        def primary_key
          associated_table.join_primary_key
        end

        def convert_to_id(value)
          case value
          when Base
            value._read_attribute(primary_key)
          else
            value
          end
        end
    end
  end
end
