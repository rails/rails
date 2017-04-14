module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      attr_reader :associated_table, :value

      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def queries
        [associated_table.association_foreign_key.to_s => ids]
      end

      private
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
          associated_table.association_primary_key
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
