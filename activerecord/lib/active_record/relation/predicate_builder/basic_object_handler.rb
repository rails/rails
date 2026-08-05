# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class BasicObjectHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value, type)
        predicate_builder.predicate_for(attribute, value, :eq, type)
      end

      private
        attr_reader :predicate_builder
    end
  end
end
