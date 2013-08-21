module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def call(attribute, value)
        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        ranges, values = values.partition { |v| v.is_a?(Range) }

        values_predicate = if values.include?(nil)
          values = values.compact

          case values.length
          when 0
            attribute.eq(nil)
          when 1
            attribute.eq(values.first).or(attribute.eq(nil))
          else
            attribute.in(values).or(attribute.eq(nil))
          end
        else
          attribute.in(values)
        end

        array_predicates = ranges.map { |range| attribute.in(range) }
        array_predicates << values_predicate
        array_predicates.inject { |composite, predicate| composite.or(predicate) }
      end
    end
  end
end
