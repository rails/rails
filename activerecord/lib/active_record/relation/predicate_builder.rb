require 'active_record/core_ext/symbol'

module ActiveRecord
  class PredicateBuilder # :nodoc:
    class Operator
      attr_reader :target, :operator
      def initialize(target, operator)
        @target, @operator = target, operator.to_sym
      end
      def to_sym
        self
      end
    end

    def self.build_from_hash(engine, attributes, default_table)
      attributes.map do |column, value|
        table = default_table

        if value.is_a?(Hash)
          table = Arel::Table.new(column, engine)
          build_from_hash(engine, value, table)
        else
          if column.is_a?(Operator)
            build(table[column.target], value, column.operator)
          else
            column = column.to_s

            if column.include?('.')
              table_name, column = column.split('.', 2)
              table = Arel::Table.new(table_name, engine)
            end

            build(table[column.to_sym], value)
          end
        end
      end.flatten
    end

    def self.references(attributes)
      attributes.map do |key, value|
        if value.is_a?(Hash)
          key
        else
          key = key.to_s
          key.split('.').first.to_sym if key.include?('.')
        end
      end.compact
    end

    private
      def self.build(attribute, value, operator = nil)
        if operator && !(operator == :not)
          return attribute.send(operator, value)
        else
          in_pred, eq_pred = :in, :eq
          if operator == :not
            in_pred, eq_pred = :not_in, :not_eq
          end
          case value
          when ActiveRecord::Relation
            value = value.select(value.klass.arel_table[value.klass.primary_key]) if value.select_values.empty?
            attribute.send(in_pred, value.arel.ast)
          when Array, ActiveRecord::Associations::CollectionProxy
            values = value.to_a.map {|x| x.is_a?(ActiveRecord::Model) ? x.id : x}
            ranges, values = values.partition {|v| v.is_a?(Range)}

            values_predicate = if values.include?(nil)
              values = values.compact

              case values.length
              when 0
                attribute.send(eq_pred, nil)
              when 1
                attribute.send(eq_pred, values.first).or(attribute.send(eq_pred, nil))
              else
                attribute.send(in_pred, values).or(attribute.send(eq_pred, nil))
              end
            else
              attribute.send(in_pred, values)
            end

            array_predicates = ranges.map { |range| attribute.in(range) }
            array_predicates << values_predicate
            array_predicates.inject { |composite, predicate| composite.or(predicate) }
          when Range
            attribute.send(in_pred, value)
          when ActiveRecord::Model
            attribute.send(eq_pred, value.id)
          when Class
            # FIXME: I think we need to deprecate this behavior
            attribute.send(eq_pred, value.name)
          else
            attribute.send(eq_pred, value)
          end
        end
      end
  end
end
