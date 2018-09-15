# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        return attribute.in([]) if value.empty?

        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        nils, values = values.partition(&:nil?)
        ranges, values = values.partition { |v| v.is_a?(Range) }

        values_predicate =
          case values.length
          when 0 then NullPredicate
          when 1 then predicate_builder.build(attribute, values.first)
          else
            values.map! do |v|
              bind = predicate_builder.build_bind_attribute(attribute.name, v)
              bind if bind.value.boundable?
            end.compact!
            values.empty? ? NullPredicate : attribute.in(values)
          end

        unless nils.empty?
          values_predicate = values_predicate.or(predicate_builder.build(attribute, nil))
        end

        array_predicates = ranges.map { |range| predicate_builder.build(attribute, range) }
        array_predicates.unshift(values_predicate)
        array_predicates.inject(&:or)
      end

      protected

        attr_reader :predicate_builder

        module NullPredicate # :nodoc:
          def self.or(other)
            other
          end
        end
    end
  end
end
