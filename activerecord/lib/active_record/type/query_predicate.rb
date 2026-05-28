# frozen_string_literal: true

module ActiveRecord
  module Type
    module QueryPredicate # :nodoc:
      def query_transformable?
        false
      end

      def query_attribute(attribute)
        attribute
      end

      def query_value(attribute, value, predicate_builder:)
        predicate_builder.build_bind_attribute(attribute.name, value, self)
      end
    end
  end
end
