module ActiveRecord
  class PredicateBuilder

    def initialize(engine)
      @engine = engine
    end

    def build_from_hash(attributes, default_table)
      predicates = attributes.map do |column, value|
        table = default_table

        if value.is_a?(Hash)
          table = Arel::Table.new(column, :engine => @engine)
          build_from_hash(value, table)
        else
          column = column.to_s

          if column.include?('.')
            table_name, column = column.split('.', 2)
            table = Arel::Table.new(table_name, :engine => @engine)
          end

          unless attribute = table[column]
            raise StatementInvalid, "No attribute named `#{column}` exists for table `#{table.name}`"
          end

          case value
          when Array, ActiveRecord::Associations::AssociationCollection, ActiveRecord::Relation
            values = value.to_a
            attribute.in(values)
          when Range
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
