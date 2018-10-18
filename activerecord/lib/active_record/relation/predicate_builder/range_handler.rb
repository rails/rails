# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RangeHandler # :nodoc:
      class RangeWithBinds < Struct.new(:begin, :end)
        def exclude_end?
          false
        end
      end

      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        begin_bind = predicate_builder.build_bind_attribute(attribute.name, value.begin)
        end_bind = predicate_builder.build_bind_attribute(attribute.name, value.end)

        if begin_bind.value.infinity?
          if end_bind.value.infinity?
            attribute.not_in([])
          elsif value.exclude_end?
            attribute.lt(end_bind)
          else
            attribute.lteq(end_bind)
          end
        elsif end_bind.value.infinity?
          attribute.gteq(begin_bind)
        elsif value.exclude_end?
          attribute.gteq(begin_bind).and(attribute.lt(end_bind))
        else
          attribute.between(RangeWithBinds.new(begin_bind, end_bind))
        end
      end

      private
        attr_reader :predicate_builder
    end
  end
end
