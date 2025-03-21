# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RegexpHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        unless value.options == 0
          raise ArgumentError, "Regexp for #{attribute.name} must not have modifiers"
        end

        attribute.matches_regexp(value.source)
      end

      private
        attr_reader :predicate_builder
    end
  end
end
