# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      RangeWithBinds = Struct.new(:begin, :end, :exclude_end?)

      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        begin_bind = predicate_builder.build_bind_attribute(attribute.name, value.begin)
        end_bind = predicate_builder.build_bind_attribute(attribute.name, value.end)
        attribute.between(RangeWithBinds.new(begin_bind, end_bind, value.exclude_end?))
      end

      private
        attr_reader :predicate_builder
    end
  end
end
