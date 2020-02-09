# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class SqlLiteralHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        attribute.in(value)
      end

      private
        attr_reader :predicate_builder
    end
  end
end
