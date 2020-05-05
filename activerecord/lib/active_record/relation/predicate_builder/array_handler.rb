# frozen_string_literal: true

require "active_support/core_ext/array/extract"

module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        return attribute.in([]) if value.empty?

        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        nils = values.extract!(&:nil?)
        ranges = values.extract! { |v| v.is_a?(Range) }

        values_predicate =
          case values.length
          when 0 then NullPredicate
          when 1 then predicate_builder.build(attribute, values.first)
          else attribute.in(values)
          end

        if nils.empty?
          return values_predicate if ranges.empty?
        else
          values_predicate = values_predicate.or(predicate_builder.build(attribute, nil))
        end

        array_predicates = ranges.map! { |range| predicate_builder.build(attribute, range) }
        array_predicates.inject(values_predicate, &:or)
      end

      private
        attr_reader :predicate_builder

        module NullPredicate # :nodoc:
          def self.or(other)
            other
          end
        end
    end
  end
end
