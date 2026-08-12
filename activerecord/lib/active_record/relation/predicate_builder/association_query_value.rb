# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(reflection, value, model)
        @reflection = reflection
        @value = value
        @model = model
      end

      def queries
        key = ActiveRecord::Key.for(reflection.join_foreign_key)
        id_list = ids
        id_list = id_list.pluck(primary_key) if key.composite? && id_list.is_a?(Relation)

        clauses = key.where_clauses(id_list)
        return clauses unless key.composite? && reflection.belongs_to?

        if value.is_a?(Array)
          # `ids` and `where_clauses` preserve one clause per association value.
          clauses.zip(value).map do |clause, association|
            association.nil? ? prune_shared_columns(clause) : clause
          end
        elsif value.nil?
          clauses.map { |clause| prune_shared_columns(clause) }
        else
          clauses
        end
      end

      private
        attr_reader :reflection, :value, :model

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
          reflection.join_primary_key
        end

        def primary_type
          reflection.join_primary_type
        end

        def polymorphic_name
          reflection.polymorphic_name
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

        # A `nil` association is queried by `IS NULL` on the foreign key, but
        # owner key columns don't identify the target row and can contradict a
        # scope on the owner.
        def prune_shared_columns(clause)
          pruned = clause.except(*shared_columns)
          # An empty predicate would match every record, so retain the original
          # clause when the entire foreign key identifies the owner.
          pruned.empty? ? clause : pruned
        end

        def shared_columns
          Array(reflection.join_foreign_key) & model.composite_query_constraints_list
        end
    end
  end
end
