module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      RangeWithBinds = Struct.new(:begin, :end, :exclude_end?)

      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        if value.begin.respond_to?(:infinite?) && value.begin.infinite?
          if value.end.respond_to?(:infinite?) && value.end.infinite?
            attribute.not_in([])
          elsif value.exclude_end?
            attribute.lt(value.end)
          else
            attribute.lteq(value.end)
          end
        elsif value.end.respond_to?(:infinite?) && value.end.infinite?
          attribute.gteq(value.begin)
        elsif value.exclude_end?
          attribute.gteq(value.begin).and(attribute.lt(value.end))
        else
          attribute.between(value)
        end
      end

      protected

      attr_reader :predicate_builder
    end
  end
end
