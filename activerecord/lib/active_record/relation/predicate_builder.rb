module ActiveRecord
  class PredicateBuilder # :nodoc:
    def self.build_from_hash(engine, attributes, default_table)
      queries = []

      attributes.each do |column, value|
        table = default_table

        if value.is_a?(Hash)
          table       = Arel::Table.new(column, engine)
          association = engine.reflect_on_association(column.to_sym)

          value.each do |k, v|
            if association && rk = find_reflection_key(k, association.klass, v)
              if rk[:foreign_type]
                queries << build(table[rk[:foreign_type]], v.class.base_class)
              end

              k = rk[:foreign_key]
            end

            queries << build(table[k.to_sym], v)
          end
        else
          column = column.to_s

          if column.include?('.')
            table_name, column = column.split('.', 2)
            table = Arel::Table.new(table_name, engine)
          end

          if rk = find_reflection_key(column, engine, value)
            if rk[:foreign_type]
              queries << build(table[rk[:foreign_type]], value.class.base_class)
            end

            column = rk[:foreign_key]
          end

          queries << build(table[column.to_sym], value)
        end
      end

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

    # Find the foreign key when using queries such as:
    # Post.where(:author => author)
    #
    # For polymorphic relationships, find the foreign key and type:
    # PriceEstimate.where(:estimate_of => treasure)
    def self.find_reflection_key(parent_column, model, value)
      # value must be an ActiveRecord object
      return nil unless value.class < Model::Tag

      if reflection = model.reflections[parent_column.to_sym]
        if reflection.options[:polymorphic]
          {
            :foreign_key  => reflection.foreign_key,
            :foreign_type => reflection.foreign_type
          }
        else
          { :foreign_key => reflection.foreign_key }
        end
      end
    end

    private
      def self.build(attribute, value)
        case value
        when Array, ActiveRecord::Associations::CollectionProxy
          values = value.to_a.map {|x| x.is_a?(ActiveRecord::Model) ? x.id : x}
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
        when ActiveRecord::Model
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
