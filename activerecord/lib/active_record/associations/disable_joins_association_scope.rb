# frozen_string_literal: true

module ActiveRecord
  module Associations
    class DisableJoinsAssociationScope < AssociationScope # :nodoc:
      def scope(association, routes = nil)
        source_reflection = association.reflection
        owner = association.owner
        unscoped = association.klass.unscoped
        routes ||= source_reflection.association_route_chain(origin_class: owner.class, destination_class: association.klass)
        reverse_chain = get_chain(source_reflection, association, unscoped.alias_tracker, routes).reverse

        last_reflection, last_ordered, last_join_ids = last_scope_chain(reverse_chain, owner)

        add_constraints(last_reflection, last_reflection.association_route.destination_key.name, last_join_ids, owner, last_ordered)
      end

      private
        def last_scope_chain(reverse_chain, owner)
          first_item = reverse_chain.shift
          first_route = first_item.association_route
          first_scope = [first_item, false, [first_route.origin_key.value_of(owner)]]

          reverse_chain.inject(first_scope) do |(reflection, ordered, join_ids), next_reflection|
            key = reflection.association_route.destination_key.name
            records = add_constraints(reflection, key, join_ids, owner, ordered)
            origin_key = next_reflection.association_route.origin_key.name
            record_ids = records.pluck(origin_key)
            records_ordered = records && records.order_values.any?

            [next_reflection, records_ordered, record_ids]
          end
        end

        def add_constraints(reflection, key, join_ids, owner, ordered)
          scope = reflection.build_scope(reflection.aliased_table)
          predicate = scope.where(key => join_ids).where_clause.ast
          scope.where!(query_constraint(predicate))

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
    end
  end
end
