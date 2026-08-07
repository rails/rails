# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class BasicObjectHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        bind = predicate_builder.build_bind_attribute(attribute.name, value)
        attribute.eq(bind)
      end

      private
        attr_reader :predicate_builder
    end
  end
end
