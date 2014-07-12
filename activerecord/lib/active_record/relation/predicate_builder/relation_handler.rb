module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.select_values.empty?
          value = value.select(value.klass.arel_table[value.klass.primary_key])
        end

        attribute.in(value.arel.ast)
      end
    end
  end
end
