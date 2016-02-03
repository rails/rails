module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.select_values.empty?
          value = value.select(value.klass.arel_attribute(value.klass.primary_key, value.klass.arel_table))
        end

        attribute.in(value.arel)
      end
    end
  end
end
