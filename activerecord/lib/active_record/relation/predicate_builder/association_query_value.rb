# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def queries
        if associated_table.join_foreign_key.is_a?(Array)
          id_list = ids
          id_list = id_list.pluck(primary_key) if id_list.is_a?(Relation)

          id_list.map { |ids_set| associated_table.join_foreign_key.zip(ids_set).to_h }
        else
          [ associated_table.join_foreign_key => ids ]
        end
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
            [convert_to_id(value)]
          end
        end

        def primary_key
          associated_table.join_primary_key
        end

        def convert_to_id(value)
          return primary_key.map { |pk| value.public_send(pk) } if primary_key.is_a?(Array)

          if value.respond_to?(primary_key)
            value.public_send(primary_key)
          else
            value
          end
        end
    end
  end
end
