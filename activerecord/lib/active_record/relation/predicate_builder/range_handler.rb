# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      RangeWithBinds = Struct.new(:begin, :end, :exclude_end?)

      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value, type)
        predicate_builder.range_predicate_for(attribute, value, type)
      end

      private
        attr_reader :predicate_builder
    end
  end
end
