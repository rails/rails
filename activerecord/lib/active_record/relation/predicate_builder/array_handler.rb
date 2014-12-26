require 'active_support/core_ext/string/filters'

module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def call(attribute, value)
        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        nils, values = values.partition(&:nil?)

        if values.any? { |val| val.is_a?(Array) }
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing a nested array to Active Record finder methods is
            deprecated and will be removed. Flatten your array before using
            it for 'IN' conditions.
          MSG

          values = values.flatten
        end

        return attribute.in([]) if values.empty? && nils.empty?

        ranges, values = values.partition { |v| v.is_a?(Range) }

        values_predicate =
          case values.length
          when 0 then NullPredicate
          when 1 then attribute.eq(values.first)
          else attribute.in(values)
          end

        unless nils.empty?
          values_predicate = values_predicate.or(attribute.eq(nil))
        end

        array_predicates = ranges.map { |range| attribute.between(range) }
        array_predicates.unshift(values_predicate)
        array_predicates.inject { |composite, predicate| composite.or(predicate) }
      end

      module NullPredicate # :nodoc:
        def self.or(other)
          other
        end
      end
    end
  end
end
