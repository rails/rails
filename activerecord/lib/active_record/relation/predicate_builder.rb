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
          build_from_hash(value, arel_table)
        else
          column = column.to_s

          if column.include?('.')
            table_name, column = column.split('.', 2)
            arel_table = Arel::Table.new(table_name, @engine)
          end

          attribute = arel_table[column] || Arel::Attribute.new(arel_table, column.to_sym)

          case value
          when Array, Range, ActiveRecord::Associations::AssociationCollection, ActiveRecord::NamedScope::Scope
            attribute.in(value)
          else
            attribute.eq(value)
          end
        end
      end

      predicates.flatten
    end

  end
end
