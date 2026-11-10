# frozen_string_literal: true

module ActiveRecord
  module Associations
    class DisableJoinsAssociationScope < AssociationScope # :nodoc:
      # The ids a link of the chain is looked up by, plucked from the previous
      # link, and how strongly that link ordered them.
      Lookup = Data.define(:ids, :order_rank) # :nodoc:

      def scope(association, routes = nil)
        source_reflection = association.reflection
        owner = association.owner
        unscoped = association.klass.unscoped
        routes ||= source_reflection.association_route_chain(origin_class: owner.class, destination_class: association.klass)
        reverse_chain = get_chain(source_reflection, association, unscoped.alias_tracker, routes).reverse

        first_route = reverse_chain.first.association_route
        lookup = Lookup.new(ids: [first_route.origin_key.value_of(owner)], order_rank: 0)

        reverse_chain.each_cons(2) do |reflection, next_reflection|
          records = add_constraints(reflection, lookup, owner)
          lookup = Lookup.new(
            ids: records.pluck(next_reflection.association_route.origin_key.name),
            order_rank: order_rank(records)
          )
        end

        add_constraints(reverse_chain.last, lookup, owner)
      end

      private
        def add_constraints(reflection, lookup, owner)
          key = reflection.association_route.destination_key.name
          scope = reflection.build_scope(reflection.aliased_table)
          predicate = scope.where(key => lookup.ids).where_clause.ast
          scope._where!(query_constraint(predicate))

          relation = reflection.klass.scope_for_association
          scope.merge!(
            relation.except(:select, :create_with, :includes, :preload, :eager_load, :joins, :left_outer_joins)
          )

          scope = reflection.constraints.inject(scope) do |memo, scope_chain_item|
            item = eval_scope(reflection, scope_chain_item, owner)
            scope.unscope!(*item.unscope_values)
            scope.where_clause += item.where_clause
            scope.order_values = item.order_values | scope.order_values
            scope.default_order_values = item.default_order_values | scope.default_order_values
            scope
          end

          if order_rank(scope) < lookup.order_rank
            split_scope = DisableJoinsAssociationRelation.create(scope.model, key, lookup.ids)
            split_scope.where_clause += scope.where_clause
            split_scope
          else
            scope
          end
        end

        # How strongly a link is ordered: not at all, only by a default order, or by
        # an explicit one. A link keeps the order of the previous one unless it is
        # ordered at least as strongly, as an explicit order on any link of a joined
        # chain takes over from the default ones.
        def order_rank(scope)
          if !scope.order_values.empty?
            2
          elsif !scope.default_order_values.empty?
            1
          else
            0
          end
        end
    end
  end
end
