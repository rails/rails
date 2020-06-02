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
          else
            if nils.empty? && ranges.empty?
              return Arel::Nodes::HomogeneousIn.new(values, attribute, :in)
            else
              attribute.in values.map { |v|
                predicate_builder.build_bind_attribute(attribute.name, v)
              }
            end
          end

        unless nils.empty?
          values_predicate = values_predicate.or(predicate_builder.build(attribute, nil))
        end

        array_predicates = ranges.map { |range| predicate_builder.build(attribute, range) }
        array_predicates.unshift(values_predicate)
        array_predicates.inject(&:or)
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
