module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      def call(attribute, value)
        attribute.between(value)
      end
    end
  end
end
