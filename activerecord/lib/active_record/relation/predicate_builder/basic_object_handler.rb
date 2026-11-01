# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class BasicObjectHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        value = predicate_builder.predicate_value(attribute, value)
        attribute.eq(value)
      end

      private
        attr_reader :predicate_builder
    end
  end
end
