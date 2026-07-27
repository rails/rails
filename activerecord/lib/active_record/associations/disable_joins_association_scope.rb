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

        add_constraints(last_reflection, Array(last_reflection.join_query_constraints_primary_key), last_join_ids, owner, last_ordered)
      end

      private
        def last_scope_chain(reverse_chain, owner)
          first_item = reverse_chain.shift
          first_scope = [first_item, false, [owner_query_constraint_values(first_item, owner)]]

          reverse_chain.inject(first_scope) do |(reflection, ordered, join_ids), next_reflection|
            key = Array(reflection.join_query_constraints_primary_key)
            records = add_constraints(reflection, key, join_ids, owner, ordered)
            record_ids = pluck_query_constraint_values(records, next_reflection)
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

        # Reads the owner's values for every column the reflection needs to query
        # against (foreign key plus any additive +query_constraints+), returning a
        # composite tuple. Uses +join_query_constraints_foreign_key+ (delegated on
        # every chain reflection) rather than the scalar +join_foreign_key+ so
        # decoupled query constraints participate in each hop.
        def owner_query_constraint_values(reflection, owner)
          Array(reflection.join_query_constraints_foreign_key).map do |key|
            owner._read_attribute(key)
          end
        end

        # Plucks the columns the next hop will query on (its
        # +join_query_constraints_foreign_key+) from the records just loaded,
        # returning a list of composite tuples. Single-column hops return
        # one-element tuples so +where(key => join_ids)+ and the ordered
        # +DisableJoinsAssociationRelation+ grouping stay shape-consistent with
        # multi-column (decoupled query constraint) hops.
        def pluck_query_constraint_values(records, reflection)
          foreign_keys = Array(reflection.join_query_constraints_foreign_key)

          if foreign_keys.size == 1
            records.pluck(foreign_keys.first).map { |id| [id] }
          else
            records.pluck(*foreign_keys)
          end
        end
    end
  end
end
