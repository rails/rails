module ActiveRecord
  module Associations
    class AssociationScope #:nodoc:
      def self.scope(association, connection)
        INSTANCE.scope association, connection
      end

      class BindSubstitution
        def initialize(block)
          @block = block
        end

        def bind_value(scope, column, value, connection)
          substitute = connection.substitute_at(column)
          scope.bind_values += [[column, @block.call(value)]]
          substitute
        end
      end

      def self.create(&block)
        block = block ? block : lambda { |val| val }
        new BindSubstitution.new(block)
      end

      def initialize(bind_substitution)
        @bind_substitution = bind_substitution
      end

      INSTANCE = create

      def scope(association, connection)
        klass         = association.klass
        reflection    = association.reflection
        scope         = klass.unscoped
        owner         = association.owner
        alias_tracker = AliasTracker.create connection, association.klass.table_name, klass.type_caster
        chain_head, chain_tail = get_chain(reflection, association, alias_tracker)

        scope.extending! Array(reflection.options[:extend])
        add_constraints(scope, owner, klass, reflection, connection, chain_head, chain_tail)
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

      private
      def join(table, constraint)
        table.create_join(table, table.create_on(constraint), join_type)
      end

      def column_for(table_name, column_name, connection)
        columns = connection.schema_cache.columns_hash(table_name)
        columns[column_name]
      end

      def bind_value(scope, column, value, connection)
        @bind_substitution.bind_value scope, column, value, connection
      end

      def bind(scope, table_name, column_name, value, connection)
        column   = column_for table_name, column_name, connection
        bind_value scope, column, value, connection
      end

      def last_chain_scope(scope, table, reflection, owner, connection, association_klass)
        join_keys = reflection.join_keys(association_klass)
        key = join_keys.key
        foreign_key = join_keys.foreign_key

        bind_val = bind scope, table.table_name, key.to_s, owner[foreign_key], connection
        scope    = scope.where(table[key].eq(bind_val))

        if reflection.type
          value    = owner.class.base_class.name
          bind_val = bind scope, table.table_name, reflection.type, value, connection
          scope    = scope.where(table[reflection.type].eq(bind_val))
        else
          scope
        end
      end

      def next_chain_scope(scope, table, reflection, connection, association_klass, foreign_table, next_reflection)
        join_keys = reflection.join_keys(association_klass)
        key = join_keys.key
        foreign_key = join_keys.foreign_key

        constraint = table[key].eq(foreign_table[foreign_key])

        if reflection.type
          value    = next_reflection.klass.base_class.name
          bind_val = bind scope, table.table_name, reflection.type, value, connection
          scope    = scope.where(table[reflection.type].eq(bind_val))
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

      def add_constraints(scope, owner, association_klass, refl, connection, chain_head, chain_tail)
        owner_reflection = chain_tail
        table = owner_reflection.alias_name
        scope = last_chain_scope(scope, table, owner_reflection, owner, connection, association_klass)

        reflection = chain_head
        loop do
          break unless reflection
          table = reflection.alias_name

          unless reflection == chain_tail
            next_reflection = reflection.next
            foreign_table = next_reflection.alias_name
            scope = next_chain_scope(scope, table, reflection, connection, association_klass, foreign_table, next_reflection)
          end

          # Exclude the scope of the association itself, because that
          # was already merged in the #scope method.
          reflection.constraints.each do |scope_chain_item|
            item  = eval_scope(reflection.klass, scope_chain_item, owner)

            if scope_chain_item == refl.scope
              scope.merge! item.except(:where, :includes, :bind)
            end

            reflection.all_includes do
              scope.includes! item.includes_values
            end

            scope.where_values += item.where_values
            scope.bind_values  += item.bind_values
            scope.order_values |= item.order_values
          end

          reflection = reflection.next
        end

        scope
      end

      def eval_scope(klass, scope, owner)
        klass.unscoped.instance_exec(owner, &scope)
      end
    end
  end
end
