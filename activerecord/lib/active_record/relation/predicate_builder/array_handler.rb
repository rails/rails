module ActiveRecord
  class PredicateBuilder
    class ArrayHandler # :nodoc:
      def call(attribute, value)
        values = value.map { |x| x.is_a?(Base) ? x.id : x }
        ranges, values = values.partition { |v| v.is_a?(Range) }

        array_predicates = ranges.map { |range| attribute.in(range) }
        if values.present?
          array_predicates << values_predicate(attribute, values)
        end

        array_predicates.inject { |composite, predicate| composite.or(predicate) }
      end

      private

      def values_predicate(attribute, values)
        if values.include?(nil)
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
      end
    end
  end
end
