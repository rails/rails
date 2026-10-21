# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module Associations
    class AssociationScope # :nodoc:
      def self.scope(association, routes = nil)
        INSTANCE.scope(association, routes)
      end

      def self.create(&block)
        block ||= lambda { |owner, column| owner.read_attribute(column) }
        new(block)
      end

      def initialize(value_reader)
        @value_reader = value_reader
      end

      INSTANCE = create

      def scope(association, routes = nil)
        klass = association.klass
        reflection = association.reflection
        scope = klass.unscoped
        owner = association.owner
        routes ||= reflection.association_route_chain(origin_class: owner.class, destination_class: klass)
        chain = get_chain(reflection, association, scope.alias_tracker, routes)

        extensions = reflection.extensions
        scope.extending!(extensions) unless extensions.empty?

        scope = add_constraints(scope, owner, chain)
        scope.default_order!(reflection.options[:default_order]) if reflection.options[:default_order].present?
        scope.limit!(1) unless reflection.collection?
        scope
      end

      private
        attr_reader :value_reader

        def join(table, constraint)
          Arel::Nodes::LeadingJoin.new(table, Arel::Nodes::On.new(constraint))
        end

        def last_chain_scope(scope, reflection, owner)
          table = reflection.aliased_table
          route = reflection.association_route

          route.each_constraint do |origin_column, destination_column|
            value = value_reader.call(owner, origin_column)
            scope = apply_scope(scope, table, destination_column, value, create_default: false)
          end

          route.each_reference do |origin_column, destination_column|
            value = value_reader.call(owner, origin_column)
            scope = apply_scope(scope, table, destination_column, value)
          end

          route.destination_fixed_values.each do |column, value|
            scope = apply_scope(scope, table, column, value)
          end

          scope
        end

        def next_chain_scope(scope, reflection, next_reflection)
          table = reflection.aliased_table
          foreign_table = next_reflection.aliased_table

          predicate_builder = scope.predicate_builder
          route = reflection.association_route
          constraints = route.each_match.map do |origin_column, destination_column|
            destination_attribute = predicate_builder.predicate_attribute(table[destination_column])
            origin_attribute = predicate_builder.predicate_attribute(foreign_table[origin_column])

            destination_attribute.eq(origin_attribute)
          end.inject(&:and)

          route.destination_fixed_values.each do |column, value|
            scope = apply_scope(scope, table, column, value)
          end

          scope.joins!(join(foreign_table, constraints))
        end

        class ReflectionProxy < SimpleDelegator # :nodoc:
          attr_reader :aliased_table

          def initialize(reflection, aliased_table, route)
            super(reflection)
            @aliased_table = aliased_table
            @route = route
          end

          def association_route(**)
            @route
          end

          def all_includes(&); nil; end
        end

        def get_chain(reflection, association, tracker, routes)
          name = reflection.name
          chain = []
          reflection.chain.zip(routes) do |refl, route|
            if chain.empty?
              chain << Reflection::RuntimeReflection.new(reflection, association, route)
            else
              aliased_table = tracker.aliased_table_for(refl.klass.arel_table) do
                refl.alias_candidate(name)
              end
              chain << ReflectionProxy.new(refl, aliased_table, route)
            end
          end
          chain
        end

        def add_constraints(scope, owner, chain)
          scope = last_chain_scope(scope, chain.last, owner)

          chain.each_cons(2) do |reflection, next_reflection|
            scope = next_chain_scope(scope, reflection, next_reflection)
          end

          chain_head = chain.first
          chain.reverse_each do |reflection|
            reflection.constraints.each do |scope_chain_item|
              item = eval_scope(reflection, scope_chain_item, owner)

              if scope_chain_item == chain_head.scope
                scope.merge! item.except(:where, :includes, :unscope, :order)
              elsif !item.references_values.empty?
                item.joins_values = item.joins_values.reject { |join| redundant_join?(item, chain, join) }
                scope.merge! item.only(:joins, :left_outer_joins)

                associations = item.eager_load_values | item.includes_values

                unless associations.empty?
                  scope.joins! item.construct_join_dependency(associations, Arel::Nodes::OuterJoin)
                end
              end

              reflection.all_includes do
                scope.includes_values |= item.includes_values
              end

              scope.unscope!(*item.table_name_qualified_unscope_values)
              scope.where_clause += item.where_clause
              scope.order_values = item.order_values | scope.order_values
              scope.default_order_values = item.default_order_values | scope.default_order_values
            end
          end

          scope
        end

        def apply_scope(scope, table, key, value, create_default: true)
          if scope.table == table && create_default
            scope.where!(key => value)
          else
            if scope.table != table
              scope.references_values |= [Arel.sql(table.name, retryable: true)]
              predicate_builder = TableMetadata.new(table.klass, table).predicate_builder
            else
              predicate_builder = scope.predicate_builder
            end

            predicate = predicate_builder[key, value]
            predicate = query_constraint(predicate) unless create_default
            scope.where!(predicate)
          end
        end

        def query_constraint(predicate)
          # WhereClause#to_h extracts ungrouped equalities for scope_for_create, so by
          # grouping here, we hide query-only constraints from that extraction and avoid
          # assigning them to new records.
          Arel::Nodes::Grouping.new(predicate)
        end

        def redundant_join?(item, chain, join)
          return false unless join.is_a?(Symbol)

          reflection = item.model._reflect_on_association(join)

          # Dropping a collection join would change how many rows the query
          # returns, so only singular ones are considered redundant here.
          return false unless reflection && !reflection.collection? && !reflection.through_reflection?

          chain.drop(1).any? { |chain_reflection| chain_reflection == reflection }
        end

        def eval_scope(reflection, scope, owner)
          relation = reflection.build_scope(reflection.aliased_table)
          relation.instance_exec(owner, &scope) || relation
        end
    end
  end
end
