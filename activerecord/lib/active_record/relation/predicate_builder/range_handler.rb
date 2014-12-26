module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        value = QuotedRange.new(
          predicate_builder.type_cast_for_database(attribute.name, value.begin),
          predicate_builder.type_cast_for_database(attribute.name, value.end),
          value.exclude_end?,
        )
        attribute.between(value)
      end

      protected

      attr_reader :predicate_builder
    end

    class QuotedRange # :nodoc:
      attr_reader :begin, :end, :exclude_end
      alias_method :exclude_end?, :exclude_end

      def initialize(begin_val, end_val, exclude)
        @begin = begin_val
        @end = end_val
        @exclude_end = exclude
      end
    end
  end
end
