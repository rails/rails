module ActiveRecord
  class PredicateBuilder
    class BaseHandler # :nodoc:
      def call(attribute, value)
        attribute.eq(value.id)
      end
    end
  end
end
