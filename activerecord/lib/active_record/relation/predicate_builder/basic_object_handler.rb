module ActiveRecord
  class PredicateBuilder
    class BasicObjectHandler # :nodoc:
      def call(attribute, value)
        attribute.eq(value)
      end
    end
  end
end
