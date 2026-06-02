# frozen_string_literal: true

require "active_support/core_ext/array/extract"

module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value, type)
        return attribute.in([]) if value.empty?

        transformable = type.transforms_query_predicates?
        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        nils = values.compact!
        ranges = values.extract! { |v| v.is_a?(Range) }

        values_predicate =
          case values.length
          when 0 then NullPredicate
          when 1 then predicate_builder.predicate_for(attribute, values.first, nil, type)
          else predicate_builder.array_predicate_for(attribute, values, type, transformable)
          end

        if nils
          values_predicate = values_predicate.or(attribute.eq(nil))
        end

        if ranges.empty?
          values_predicate
        else
          array_predicates = ranges.map! { |range| predicate_builder.range_predicate_for(attribute, range, type) }
          values_predicate.or(
            Arel::Nodes::Grouping.new Arel::Nodes::Or.new(array_predicates)
          )
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
