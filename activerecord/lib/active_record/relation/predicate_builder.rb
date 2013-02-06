module ActiveRecord
  class PredicateBuilder

    def initialize(engine)
      @engine = engine
    end

    def build_from_hash(attributes, default_table, allow_table_name = true)
      predicates = attributes.map do |column, value|
        table = default_table

        if allow_table_name && value.is_a?(Hash)
          table = Arel::Table.new(column, :engine => @engine)

          if value.empty?
            '1 = 2'
          else
            build_from_hash(value, table, false)
          end
        else
          column = column.to_s

          if allow_table_name && column.include?('.')
            table_name, column = column.split('.', 2)
            table = Arel::Table.new(table_name, :engine => @engine)
          end

          attribute = table[column] || Arel::Attribute.new(table, column)

          case value
          when Array, ActiveRecord::Associations::AssociationCollection, ActiveRecord::Relation
            values = value.to_a.map { |x|
              x.is_a?(ActiveRecord::Base) ? x.id : x
            }
            attribute.in(values)
          when Range, Arel::Relation
            attribute.in(value)
          when ActiveRecord::Base
            attribute.eq(value.id)
          when Class
            # FIXME: I think we need to deprecate this behavior
            attribute.eq(value.name)
          when Integer, ActiveSupport::Duration
            # Arel treats integers as literals, but they should be quoted when compared with strings
            attribute.eq(Arel::Nodes::SqlLiteral.new(@engine.connection.quote(value, attribute.column)))
          else
            attribute.eq(value)
          end
        end
      end

      predicates.flatten
    end

  end
end
