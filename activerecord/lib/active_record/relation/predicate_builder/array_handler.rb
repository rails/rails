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
              predicate_builder.connection.in_clause_length
              join_name = attribute.relation.table_alias || attribute.relation.name
              quoted_column_name = "#{predicate_builder.connection.quote_table_name(join_name)}.#{predicate_builder.connection.quote_column_name(attribute.name)}"
              type = attribute.type_caster

              casted_values = values.map do |raw_value|
                type.serialize2(raw_value) if type.serializable?(raw_value)
              end

              casted_values.compact!

              return Arel::Nodes::HomogeneousIn.new(quoted_column_name, casted_values, attribute, :in)
            else
              build_in(values, predicate_builder, attribute)
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

        def build_in(values, predicate_builder, attribute)
          attribute.in values.map { |v|
            predicate_builder.build_bind_attribute(attribute.name, v)
          }
        end

        module NullPredicate # :nodoc:
          def self.or(other)
            other
          end
        end
    end
  end
end
