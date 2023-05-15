# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RelationExistsHandler # :nodoc:
      def call(attribute, value)
        if value.arel_table == attribute.relation
          return ActiveRecord::PredicateBuilder::RelationInHandler.new.call(attribute, value)
        end

        if value.eager_loading?
          value = value.send(:apply_join_dependency)
        end

        correlation_clause =
          if value.select_values.present?
            value.table[value.select_values.first].eq(attribute)
          else
            if value.klass.composite_primary_key?
              raise ArgumentError, "Cannot map composite primary key #{value.klass.primary_key} to #{attribute.name}"
            else
              value.table[value.klass.primary_key].eq(attribute)
            end
          end

        value.reselect(1).where(correlation_clause).arel.exists
      end
    end
  end
end
