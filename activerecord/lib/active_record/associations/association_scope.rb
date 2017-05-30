module ActiveRecord
  module Associations
    class AssociationScope #:nodoc:
      def self.scope(association, connection)
        INSTANCE.scope(association, connection)
      end

      def self.create(&block)
        block ||= lambda { |val| val }
        new(block)
      end

      def initialize(value_transformation)
        @value_transformation = value_transformation
      end

      INSTANCE = create

      def scope(association, connection)
        klass = association.klass
        reflection = association.reflection
        scope = klass.unscoped
        owner = association.owner
        alias_tracker = AliasTracker.create connection, association.klass.table_name, klass.type_caster
        chain_head, chain_tail = get_chain(reflection, association, alias_tracker)

        scope.extending! reflection.extensions
        add_constraints(scope, owner, reflection, chain_head, chain_tail)
      end

      def join_type
        Arel::Nodes::InnerJoin
      end

      def self.get_bind_values(owner, chain)
        binds = []
        last_reflection = chain.last

        binds << last_reflection.join_id_for(owner)
        if last_reflection.type
          binds << owner.class.base_class.name
        end

        chain.each_cons(2).each do |reflection, next_reflection|
          if reflection.type
            binds << next_reflection.klass.base_class.name
          end
        end
        binds
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :value_transformation

      private
        def join(table, constraint)
          table.create_join(table, table.create_on(constraint), join_type)
        end

        def last_chain_scope(scope, table, reflection, owner)
          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          value = transform_value(owner[foreign_key])
          scope = scope.where(table.name => { key => value })

          if reflection.type
            polymorphic_type = transform_value(owner.class.base_class.name)
            scope = scope.where(table.name => { reflection.type => polymorphic_type })
          end

          scope
        end

        def transform_value(value)
          value_transformation.call(value)
        end

        def next_chain_scope(scope, table, reflection, foreign_table, next_reflection)
          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          constraint = table[key].eq(foreign_table[foreign_key])

          if reflection.type
            value = transform_value(next_reflection.klass.base_class.name)
            scope = scope.where(table.name => { reflection.type => value })
          end

          scope = scope.joins(join(foreign_table, constraint))
        end

        class ReflectionProxy < SimpleDelegator # :nodoc:
          attr_accessor :next
          attr_reader :alias_name

          def initialize(reflection, alias_name)
            super(reflection)
            @alias_name = alias_name
          end

          def all_includes; nil; end
        end

        def get_chain(reflection, association, tracker)
          name = reflection.name
          runtime_reflection = Reflection::RuntimeReflection.new(reflection, association)
          previous_reflection = runtime_reflection
          reflection.chain.drop(1).each do |refl|
            alias_name = tracker.aliased_table_for(refl.table_name, refl.alias_candidate(name))
            proxy = ReflectionProxy.new(refl, alias_name)
            previous_reflection.next = proxy
            previous_reflection = proxy
          end
          [runtime_reflection, previous_reflection]
        end

        def add_constraints(scope, owner, refl, chain_head, chain_tail)
          owner_reflection = chain_tail
          table = owner_reflection.alias_name
          scope = last_chain_scope(scope, table, owner_reflection, owner)

          reflection = chain_head
          while reflection
            table = reflection.alias_name
            next_reflection = reflection.next

            unless reflection == chain_tail
              foreign_table = next_reflection.alias_name
              scope = next_chain_scope(scope, table, reflection, foreign_table, next_reflection)
            end

            # Exclude the scope of the association itself, because that
            # was already merged in the #scope method.
            reflection.constraints.each do |scope_chain_item|
              item = eval_scope(reflection.klass, table, scope_chain_item, owner)

              if scope_chain_item == refl.scope
                scope.merge! item.except(:where, :includes)
              end

              reflection.all_includes do
                scope.includes! item.includes_values
              end

              scope.unscope!(*item.unscope_values)
              scope.where_clause += item.where_clause
              scope.order_values |= item.order_values
            end

            reflection = next_reflection
          end

          scope
        end

        def eval_scope(klass, table, scope, owner)
          predicate_builder = PredicateBuilder.new(TableMetadata.new(klass, table))
          ActiveRecord::Relation.create(klass, table, predicate_builder).instance_exec(owner, &scope)
        end
    end
  end
end
