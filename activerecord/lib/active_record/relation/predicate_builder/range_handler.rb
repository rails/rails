module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        attribute.between(value)
      end

      protected

      attr_reader :predicate_builder
    end
  end
end
