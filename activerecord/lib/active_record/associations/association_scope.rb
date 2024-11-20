# frozen_string_literal: true

module ActiveRecord
  module Associations
    class AssociationScope # :nodoc:
      def self.scope(association)
        INSTANCE.scope(association)
      end

      def self.create(&block)
        block ||= lambda { |val| val }
        new(block)
      end

      def initialize(value_transformation)
        @value_transformation = value_transformation
      end

      INSTANCE = create

      def scope(association)
        klass = association.klass
        reflection = association.reflection
        scope = klass.unscoped
        owner = association.owner
        chain = get_chain(reflection, association, scope.alias_tracker)

        scope.extending! reflection.extensions
        scope = add_constraints(scope, owner, chain)
        scope.limit!(1) unless reflection.collection?
        scope
      end

      def self.get_bind_values(owner, chain)
        binds = []
        last_reflection = chain.last

        binds.push(*last_reflection.join_id_for(owner))
        if last_reflection.type
          binds << owner.class.polymorphic_name
        end

        chain.each_cons(2).each do |reflection, next_reflection|
          if reflection.type
            binds << next_reflection.klass.polymorphic_name
          end
        end
        binds
      end

      private
        attr_reader :value_transformation

        def join(table, constraint)
          Arel::Nodes::LeadingJoin.new(table, Arel::Nodes::On.new(constraint))
        end

        def last_chain_scope(scope, reflection, owner)
          primary_key = Array(reflection.join_primary_key)
          foreign_key = Array(reflection.join_foreign_key)

          table = reflection.aliased_table
          primary_key_foreign_key_pairs = primary_key.zip(foreign_key)
          primary_key_foreign_key_pairs.each do |join_key, foreign_key|
            value = transform_value(owner._read_attribute(foreign_key))
            scope = apply_scope(scope, table, join_key, value)
          end

          if reflection.type
            polymorphic_type = transform_value(owner.class.polymorphic_name)
            scope = apply_scope(scope, table, reflection.type, polymorphic_type)
          end

          scope
        end

        def transform_value(value)
          value_transformation.call(value)
        end

        def next_chain_scope(scope, reflection, next_reflection)
          primary_key = Array(reflection.join_primary_key)
          foreign_key = Array(reflection.join_foreign_key)

          table = reflection.aliased_table
          foreign_table = next_reflection.aliased_table

          primary_key_foreign_key_pairs = primary_key.zip(foreign_key)
          constraints = primary_key_foreign_key_pairs.map do |join_primary_key, foreign_key|
            table[join_primary_key].eq(foreign_table[foreign_key])
          end.inject(&:and)

          if reflection.type
            value = transform_value(next_reflection.klass.polymorphic_name)
            scope = apply_scope(scope, table, reflection.type, value)
          end

          scope.joins!(join(foreign_table, constraints))
        end

        class ReflectionProxy < SimpleDelegator # :nodoc:
          attr_reader :aliased_table

          def initialize(reflection, aliased_table)
            super(reflection)
            @aliased_table = aliased_table
          end

          def all_includes; nil; end
        end

        def get_chain(reflection, association, tracker)
          name = reflection.name
          chain = [Reflection::RuntimeReflection.new(reflection, association)]
          reflection.chain.drop(1).each do |refl|
            aliased_table = tracker.aliased_table_for(refl.klass.arel_table) do
              refl.alias_candidate(name)
            end
            chain << ReflectionProxy.new(refl, aliased_table)
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
                scope.merge! item.only(:joins, :left_outer_joins)

                associations = item.eager_load_values | item.includes_values

                unless associations.empty?
                  scope.joins! item.construct_join_dependency(associations, Arel::Nodes::OuterJoin)
                end
              end

              reflection.all_includes do
                scope.includes_values |= item.includes_values
              end

              scope.unscope!(*item.unscope_values)
              scope.where_clause += item.where_clause
              scope.order_values = item.order_values | scope.order_values
            end
          end

          scope
        end

        def apply_scope(scope, table, key, value)
          if scope.table == table
            scope.where!(key => value)
          else
            scope.where!(table.name => { key => value })
          end
        end

        def eval_scope(reflection, scope, owner)
          relation = reflection.build_scope(reflection.aliased_table)
          relation.instance_exec(owner, &scope) || relation
        end
    end
  end
end
