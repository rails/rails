# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      RangeWithBinds = Struct.new(:begin, :end, :exclude_end?)

      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        begin_bind = predicate_builder.query_value(attribute, value.begin)
        end_bind = predicate_builder.query_value(attribute, value.end)
        predicate_builder.query_attribute(attribute).between(
          RangeWithBinds.new(begin_bind, end_bind, value.exclude_end?)
        )
      end

      private
        attr_reader :predicate_builder
    end
  end
end
