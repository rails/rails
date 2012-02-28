module ActiveRecord
  module Associations
    class AssociationScope #:nodoc:
      include JoinHelper

      attr_reader :association, :alias_tracker

      delegate :klass, :owner, :reflection, :interpolate, :to => :association
      delegate :chain, :conditions, :options, :source_options, :active_record, :to => :reflection

      def initialize(association)
        @association   = association
        @alias_tracker = AliasTracker.new klass.connection
      end

      def scope
        scope = klass.unscoped
        scope = scope.extending(*Array(options[:extend]))

        # It's okay to just apply all these like this. The options will only be present if the
        # association supports that option; this is enforced by the association builder.
        scope = scope.apply_finder_options(options.slice(
          :readonly, :include, :references, :order, :limit, :joins, :group, :having, :offset, :select))

        if options[:through] && !options[:include]
          scope = scope.includes(source_options[:include])
        end

        scope = scope.uniq if options[:uniq]

        add_constraints(scope)
      end

      private

      def column_for(table_name, column_name)
        columns = alias_tracker.connection.schema_cache.columns_hash[table_name]
        columns[column_name]
      end

      def bind_value(scope, column, value)
        substitute = alias_tracker.connection.substitute_at(
          column, scope.bind_values.length)
        scope.bind_values += [[column, value]]
        substitute
      end

      def bind(scope, table_name, column_name, value)
        column   = column_for table_name, column_name
        bind_value scope, column, value
      end

      def add_constraints(scope)
        tables = construct_tables

        chain.each_with_index do |reflection, i|
          table, foreign_table = tables.shift, tables.first

          if reflection.source_macro == :has_and_belongs_to_many
            join_table = tables.shift

            scope = scope.joins(join(
              join_table,
              table[reflection.association_primary_key].
                eq(join_table[reflection.association_foreign_key])
            ))

            table, foreign_table = join_table, tables.first
          end

          if reflection.source_macro == :belongs_to
            if reflection.options[:polymorphic]
              key = reflection.association_primary_key(klass)
            else
              key = reflection.association_primary_key
            end

            foreign_key = reflection.foreign_key
          else
            key         = reflection.foreign_key
            foreign_key = reflection.active_record_primary_key
          end

          conditions = self.conditions[i]

          if reflection == chain.last
            bind_val = bind scope, table.table_name, key.to_s, owner[foreign_key]
            scope    = scope.where(table[key].eq(bind_val))

            if reflection.type
              value    = owner.class.base_class.name
              bind_val = bind scope, table.table_name, reflection.type.to_s, value
              scope    = scope.where(table[reflection.type].eq(bind_val))
            end

            conditions.each do |condition|
              if options[:through] && condition.is_a?(Hash)
                condition = { table.name => condition }
              end

              scope = scope.where(interpolate(condition))
            end
          else
            constraint = table[key].eq(foreign_table[foreign_key])

            if reflection.type
              type = chain[i + 1].klass.base_class.name
              constraint = constraint.and(table[reflection.type].eq(type))
            end

            scope = scope.joins(join(foreign_table, constraint))

            conditions.each do |condition|
              condition = interpolate(condition)
              condition = { (table.table_alias || table.name) => condition } unless i == 0

              scope = scope.where(condition)
            end
          end
        end

        scope
      end

      def alias_suffix
        reflection.name
      end

      def table_name_for(reflection)
        if reflection == self.reflection
          # If this is a polymorphic belongs_to, we want to get the klass from the
          # association because it depends on the polymorphic_type attribute of
          # the owner
          klass.table_name
        else
          reflection.table_name
        end
      end

    end
  end
end
