# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class BaseHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        predicate_builder.build(attribute, value.id)
      end

      protected

        attr_reader :predicate_builder
    end
  end
end
