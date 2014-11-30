module ActiveRecord
  class PredicateBuilder
    class PolymorphicHandler # :nodoc:
      def call(attribute, values)
        reflection, base_class, table, value = values.to_a

        type_predictate = table[reflection.foreign_type].eq(base_class.name)
        key_predictate  = case value
        when Array
          attribute.in value.map(&:id)
        when Base
          attribute.eq value.id
        when Relation
          RelationHandler.new.call(attribute, value)
        end

        type_predictate.and(key_predictate)
      end
    end
  end
end
