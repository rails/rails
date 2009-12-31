module ActiveRecord
  class PredicateBuilder

    def initialize(engine)
      @engine = engine
    end

    def build_from_hash(attributes, default_table)
      predicates = attributes.map do |column, value|
        arel_table = default_table

        if value.is_a?(Hash)
          arel_table = Arel::Table.new(column, @engine)
          build_predicate_from_hash(value, arel_table)
        else
          column = column.to_s

          if column.include?('.')
            table_name, column = column.split('.', 2)
            arel_table = Arel::Table.new(table_name, @engine)
          end

          case value
          when Array, Range, ActiveRecord::Associations::AssociationCollection, ActiveRecord::NamedScope::Scope
            arel_table[column].in(value)
          else
            arel_table[column].eq(value)
          end
        end
      end

      predicates.flatten
    end

  end
end
