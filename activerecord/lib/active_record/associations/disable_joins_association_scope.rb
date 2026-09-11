# frozen_string_literal: true

module ActiveRecord
  module Associations
    class DisableJoinsAssociationScope < AssociationScope # :nodoc:
      def scope(association)
        source_reflection = association.reflection
        owner = association.owner
        unscoped = association.klass.unscoped
        reverse_chain = get_chain(source_reflection, association, unscoped.alias_tracker).reverse

        last_reflection, last_ordered, last_join_ids = last_scope_chain(reverse_chain, owner)

        add_constraints(last_reflection, last_reflection.query_key_mapping.associated_record_columns, last_join_ids, owner, last_ordered)
      end

      private
        def last_scope_chain(reverse_chain, owner)
          first_item = reverse_chain.shift
          first_scope = [first_item, false, [first_item.query_key_mapping.values_for(owner)]]

          reverse_chain.inject(first_scope) do |(reflection, ordered, join_ids), next_reflection|
            key = reflection.query_key_mapping.associated_record_columns
            records = add_constraints(reflection, key, join_ids, owner, ordered)
            record_ids = pluck_query_key_values(records, next_reflection)
            records_ordered = records && records.order_values.any?

            [next_reflection, records_ordered, record_ids]
          end
        end

        def add_constraints(reflection, key, join_ids, owner, ordered)
          scope = reflection.build_scope(reflection.aliased_table).where(key => join_ids)

          relation = reflection.klass.scope_for_association
          scope.merge!(
            relation.except(:select, :create_with, :includes, :preload, :eager_load, :joins, :left_outer_joins)
          )

          scope = reflection.constraints.inject(scope) do |memo, scope_chain_item|
            item = eval_scope(reflection, scope_chain_item, owner)
            scope.unscope!(*item.unscope_values)
            scope.where_clause += item.where_clause
            scope.order_values = item.order_values | scope.order_values
            scope
          end

          if scope.order_values.empty? && ordered
            split_scope = DisableJoinsAssociationRelation.create(scope.model, key, join_ids)
            split_scope.where_clause += scope.where_clause
            split_scope
          else
            scope
          end
        end

        # Plucks the columns on the active-record side of the next hop. Single-
        # column hops retain a tuple shape for DisableJoinsAssociationRelation.
        def pluck_query_key_values(records, reflection)
          columns = reflection.query_key_mapping.active_record_columns

          if columns.size == 1
            records.pluck(columns.first).map { |id| [id] }
          else
            records.pluck(*columns)
          end
        end
    end
  end
end
