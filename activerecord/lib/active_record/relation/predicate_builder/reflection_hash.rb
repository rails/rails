# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    # Allows a reflection to tagalong with the values of a "where hash"
    # so we can correctly identify the associated table.
    class ReflectionHash < Hash # :nodoc:
      attr_accessor :reflection

      def self.create(reflection, values)
        instance = self[values]
        instance.reflection = reflection
        instance
      end
    end
  end
end
