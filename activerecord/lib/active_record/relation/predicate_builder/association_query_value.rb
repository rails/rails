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
            relation = value
            relation = relation.select(primary_key) if select_clause?
            relation = relation.where(primary_type => polymorphic_name) if polymorphic_clause?
            relation
          when Array
            value.map { |v| convert_to_id(v) }
          else
            [convert_to_id(value)]
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
          if primary_key.is_a?(Array)
            primary_key.map do |attribute|
              next nil if value.nil?

              if attribute == "id"
                value.id_value
              else
                value.public_send(attribute)
              end
            end
          elsif value.respond_to?(primary_key)
            value.public_send(primary_key)
          else
            value
          end
        end
    end
  end
end
