module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.select_values.empty?
          value = value.select(value.arel_attribute(value.klass.primary_key))
        end

        attribute.in(value.arel)
      end
    end
  end
end
