# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class ArelHandler # :nodoc:
      def call(attribute, value)
        attribute.eq(value)
      end
    end
  end
end
