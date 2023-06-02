# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def queries
        [ associated_table.join_foreign_key => ids ]
      end

      private
        attr_reader :associated_table, :value

        def ids
          case value
          when Relation
            relation = value
            relation = relation.select(primary_key) if select_clause?
            relation = relation.where(primary_type => polymorphic_name) if polymorphic_clause?
            relation
          when Array
            value.map { |v| convert_to_id(v) }
          else
            convert_to_id(value)
          end
        end

        def primary_key
          associated_table.join_primary_key
        end

        def primary_type
          associated_table.join_primary_type
        end

        def polymorphic_name
          associated_table.polymorphic_name_association
        end

        def select_clause?
          value.select_values.empty?
        end

        def polymorphic_clause?
          primary_type && !value.where_values_hash.has_key?(primary_type)
        end

        def convert_to_id(value)
          if value.respond_to?(primary_key)
            value.public_send(primary_key)
          else
            value
          end
        end
    end
  end
end
