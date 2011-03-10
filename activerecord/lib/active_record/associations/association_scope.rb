module ActiveRecord
  module Associations
    class AssociationScope #:nodoc:
      attr_reader :association, :alias_tracker

      delegate :klass, :owner, :reflection, :interpolate, :to => :association
      delegate :through_reflection_chain, :through_conditions, :options, :source_options, :to => :reflection

      def initialize(association)
        @association   = association
        @alias_tracker = AliasTracker.new
      end

      def scope
        scope = klass.unscoped
        scope = scope.extending(*Array.wrap(options[:extend]))

        # It's okay to just apply all these like this. The options will only be present if the
        # association supports that option; this is enforced by the association builder.
        scope = scope.apply_finder_options(options.slice(
          :readonly, :include, :order, :limit, :joins, :group, :having, :offset))

        if options[:through] && !options[:include]
          scope = scope.includes(source_options[:include])
        end

        if select = select_value
          scope = scope.select(select)
        end

        add_constraints(scope)
      end

      private

      def select_value
        select_value = options[:select]

        if reflection.collection?
          select_value ||= options[:uniq] && "DISTINCT #{reflection.quoted_table_name}.*"
        end

        if reflection.macro == :has_and_belongs_to_many
          select_value ||= reflection.klass.arel_table[Arel.star]
        end

        select_value
      end

      def add_constraints(scope)
        tables = construct_tables

        through_reflection_chain.each_with_index do |reflection, i|
          table, foreign_table = tables.shift, tables.first

          if reflection.source_macro == :has_and_belongs_to_many
            join_table = tables.shift

            scope = scope.joins(inner_join(
              join_table, reflection,
              table[reflection.active_record_primary_key].
                eq(join_table[reflection.association_foreign_key])
            ))

            table, foreign_table = join_table, tables.first
          end

          if reflection.source_macro == :belongs_to
            key         = reflection.association_primary_key
            foreign_key = reflection.foreign_key
          else
            key         = reflection.foreign_key
            foreign_key = reflection.active_record_primary_key
          end

          if reflection == through_reflection_chain.last
            scope = scope.where(table[key].eq(owner[foreign_key]))

            through_conditions[i].each do |condition|
              if options[:through] && condition.is_a?(Hash)
                condition = { table.name => condition }
              end

              scope = scope.where(interpolate(condition))
            end
          else
            constraint = table[key].eq foreign_table[foreign_key]

            join  = inner_join(foreign_table, reflection, constraint, *through_conditions[i])
            scope = scope.joins(join)
          end
        end

        scope
      end

      def construct_tables
        tables = []
        through_reflection_chain.each do |reflection|
          tables << alias_tracker.aliased_table_for(
            table_name_for(reflection),
            table_alias_for(reflection, reflection != self.reflection)
          )

          if reflection.source_macro == :has_and_belongs_to_many
            tables << alias_tracker.aliased_table_for(
              (reflection.source_reflection || reflection).options[:join_table],
              table_alias_for(reflection, true)
            )
          end
        end
        tables
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

      def table_alias_for(reflection, join = false)
        name = alias_tracker.pluralize(reflection.name)
        name << "_#{self.reflection.name}"
        name << "_join" if join
        name
      end

      def inner_join(table, reflection, *conditions)
        conditions = sanitize_conditions(reflection, conditions)
        table.create_join(table, table.create_on(conditions))
      end

      def sanitize_conditions(reflection, conditions)
        conditions = conditions.map do |condition|
          condition = reflection.klass.send(:sanitize_sql, interpolate(condition), reflection.table_name)
          condition = Arel.sql(condition) unless condition.is_a?(Arel::Node)
          condition
        end

        conditions.length == 1 ? conditions.first : Arel::Nodes::And.new(conditions)
      end
    end
  end
end
