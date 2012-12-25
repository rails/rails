module ActiveRecord
  module Associations
    # Helper class module which gets mixed into JoinDependency::JoinAssociation and AssociationScope
    module JoinHelper #:nodoc:

      def join_type
        Arel::InnerJoin
      end

      private

      def construct_tables
        tables = []
        chain.each do |reflection|
          tables << alias_tracker.aliased_table_for(
            table_name_for(reflection),
            table_alias_for(reflection, reflection != self.reflection)
          )

          if reflection.source_macro == :has_and_belongs_to_many
            tables << alias_tracker.aliased_table_for(
              (reflection.source_reflection || reflection).join_table,
              table_alias_for(reflection, true)
            )
          end
        end
        tables
      end

      def table_name_for(reflection)
        reflection.table_name
      end

      def table_alias_for(reflection, join = false)
        name = "#{reflection.plural_name}_#{alias_suffix}"
        name << "_join" if join
        name
      end

      def join(table, constraint)
        table.create_join(table, table.create_on(constraint), join_type)
      end
    end
  end
end
