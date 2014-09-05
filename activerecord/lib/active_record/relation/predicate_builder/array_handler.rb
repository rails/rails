module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def call(attribute, value)
        if value.any? { |member| member.is_a?(Array) }
          column = attribute.relation.engine.columns_hash[attribute.name]
          unless column.respond_to?(:array) and column.array == true
            ActiveSupport::Deprecation.warn "Passing a nested array to Active Record " \
              "finder methods is deprecated and will be removed. Flatten your array " \
              "before using it for 'IN' conditions."
            value = value.flatten
          end
        end

        return attribute.in([]) if value.empty?

        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        ranges, values = values.partition { |v| v.is_a?(Range) }
        nils, values = values.partition(&:nil?)

        values_predicate =
          case values.length
          when 0 then NullPredicate
          when 1 then attribute.eq(values.first)
          else attribute.in(values)
          end

        unless nils.empty?
          values_predicate = values_predicate.or(attribute.eq(nil))
        end

        array_predicates = ranges.map { |range| attribute.in(range) }
        array_predicates << values_predicate
        array_predicates.inject { |composite, predicate| composite.or(predicate) }
      end

      module NullPredicate
        def self.or(other)
          other
        end
      end
    end
  end
end
