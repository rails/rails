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

          attribute = table[column] || Arel::Attribute.new(table, column)

          case value
          when Array, ActiveRecord::Associations::AssociationCollection, ActiveRecord::Relation
            values = value.to_a.map { |x|
              x.respond_to?(:quoted_id) ? x.quoted_id : x
            }
            attribute.in(values)
          when Range, Arel::Relation
            attribute.in(value)
          when ActiveRecord::Base
            attribute.eq(value.quoted_id)
          when Class
            # FIXME: I think we need to deprecate this behavior
            attribute.eq(value.name)
          else
            attribute.eq(value)
          end
        end
      end

      predicates.flatten
    end

  end
end
