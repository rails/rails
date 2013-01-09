module ActiveRecord
  class PredicateBuilder # :nodoc:
    def self.build_from_hash(klass, attributes, default_table)
      queries = []

      attributes.each do |column, value|
        table = default_table

        if value.is_a?(Hash)
          table       = Arel::Table.new(column, default_table.engine)
          association = klass.reflect_on_association(column.to_sym)

          if value.empty?
            queries.concat ['1 = 2']
          else
            value.each do |k, v|
              queries.concat expand(association && association.klass, table, k, v)
            end
          end
        else
          column = column.to_s

          if column.include?('.')
            table_name, column = column.split('.', 2)
            table = Arel::Table.new(table_name, default_table.engine)
          end

          queries.concat expand(klass, table, column, value)
        end
      end

      queries
    end

    def self.expand(klass, table, column, value)
      queries = []

      # Find the foreign key when using queries such as:
      # Post.where(author: author)
      #
      # For polymorphic relationships, find the foreign key and type:
      # PriceEstimate.where(estimate_of: treasure)
      if klass && value.class < Base && reflection = klass.reflect_on_association(column.to_sym)
        if reflection.polymorphic?
          queries << build(table[reflection.foreign_type], value.class.base_class)
        end

        column = reflection.foreign_key
      end

      queries << build(table[column.to_sym], value)
      queries
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
      def self.build(attribute, value)
        case value
        when Array, ActiveRecord::Associations::CollectionProxy
          values = value.to_a.map {|x| x.is_a?(Base) ? x.id : x}
          ranges, values = values.partition {|v| v.is_a?(Range)}

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
        when ActiveRecord::Relation
          value = value.select(value.klass.arel_table[value.klass.primary_key]) if value.select_values.empty?
          attribute.in(value.arel.ast)
        when Range
          attribute.in(value)
        when ActiveRecord::Base
          attribute.eq(value.id)
        when Class
          # FIXME: I think we need to deprecate this behavior
          attribute.eq(value.name)
        else
          attribute.eq(value)
        end
      end
  end
end
