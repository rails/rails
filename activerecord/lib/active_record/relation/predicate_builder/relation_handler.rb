# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.eager_loading?
          value = value.send(:apply_join_dependency)
        end

        if value.select_values.empty?
          value = value.select(value.arel_attribute(value.klass.primary_key))
        end

        value.optimizer_hints_values = value.optimizer_hints_values.select do |hint|
          value.connection.optimizer_hint_allowed_in_subquery?(hint)
        end

        attribute.in(value.arel)
      end
    end
  end
end
