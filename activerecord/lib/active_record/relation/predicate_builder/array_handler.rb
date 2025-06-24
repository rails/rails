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
        nils = values.compact!
        ranges = values.extract! { |v| v.is_a?(Range) }

        values_predicate =
          case values.length
          when 0 then NullPredicate
          when 1 then predicate_builder.build(attribute, values.first)
          else Arel::Nodes::HomogeneousIn.new(values, attribute, :in)
          end

        if nils
          values_predicate = values_predicate.or(attribute.eq(nil))
        end

        if ranges.empty?
          values_predicate
        else
          array_predicates = ranges.map! { |range| predicate_builder.build(attribute, range) }
          array_predicates.inject(values_predicate, &:or)
        end
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
