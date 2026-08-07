# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.eager_loading?
          value = value.send(:apply_join_dependency)
        end

        if value.select_values.empty?
          model = value.model
          if model.composite_primary_key?
            raise ArgumentError, "Cannot map composite primary key #{model.primary_key} to #{attribute.name}"
          else
            value = value.select(value.table[model.primary_key])
          end
        end

        attribute.in(value.arel)
      end
    end
  end
end
