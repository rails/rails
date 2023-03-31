# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.eager_loading?
          value = value.send(:apply_join_dependency)
        end

        if value.select_values.empty?
          if value.klass.composite_primary_key?
            raise ArgumentError, "Cannot map composite primary key #{value.klass.primary_key} to #{attribute.name}"
          else
            value = value.select(value.table[value.klass.primary_key])
          end
        end

        attribute.in(value.arel)
      end
    end
  end
end
