module ActiveRecord
  class PredicateBuilder # :nodoc:
    @handlers = []

    autoload :RelationHandler, 'active_record/relation/predicate_builder/relation_handler'
    autoload :ArrayHandler, 'active_record/relation/predicate_builder/array_handler'

    def self.resolve_column_aliases(klass, hash)
      hash = hash.dup
      hash.keys.grep(Symbol) do |key|
        if klass.attribute_alias? key
          hash[klass.attribute_alias(key)] = hash.delete key
        end
      end
      hash
    end

    def self.build_from_hash(klass, attributes, default_table)
      queries = []

      attributes.each do |column, value|
        table = default_table

        if value.is_a?(Hash)
          if value.empty?
            queries << '1=0'
          else
            table       = Arel::Table.new(column, default_table.engine)
            association = klass._reflect_on_association(column)

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
      if klass && reflection = klass._reflect_on_association(column)
        if reflection.polymorphic? && base_class = polymorphic_base_class_from_value(value)
          queries << build(table[reflection.foreign_type], base_class)
        end

        column = reflection.foreign_key
      end

      queries << build(table[column], value)
      queries
    end

    def self.polymorphic_base_class_from_value(value)
      case value
      when Relation
        value.klass.base_class
      when Array
        val = value.compact.first
        val.class.base_class if val.is_a?(Base)
      when Base
        value.class.base_class
      end
    end

    def self.references(attributes)
      attributes.map do |key, value|
        if value.is_a?(Hash)
          key
        else
          key = key.to_s
          key.split('.').first if key.include?('.')
        end
      end.compact
    end

    # Define how a class is converted to Arel nodes when passed to +where+.
    # The handler can be any object that responds to +call+, and will be used
    # for any value that +===+ the class given. For example:
    #
    #     MyCustomDateRange = Struct.new(:start, :end)
    #     handler = proc do |column, range|
    #       Arel::Nodes::Between.new(column,
    #         Arel::Nodes::And.new([range.start, range.end])
    #       )
    #     end
    #     ActiveRecord::PredicateBuilder.register_handler(MyCustomDateRange, handler)
    def self.register_handler(klass, handler)
      @handlers.unshift([klass, handler])
    end

    register_handler(BasicObject, ->(attribute, value) { attribute.eq(value) })
    # FIXME: I think we need to deprecate this behavior
    register_handler(Class, ->(attribute, value) { attribute.eq(value.name) })
    register_handler(Base, ->(attribute, value) { attribute.eq(value.id) })
    register_handler(Range, ->(attribute, value) { attribute.between(value) })
    register_handler(Relation, RelationHandler.new)
    register_handler(Array, ArrayHandler.new)

    def self.build(attribute, value)
      handler_for(value).call(attribute, value)
    end
    private_class_method :build

    def self.handler_for(object)
      @handlers.detect { |klass, _| klass === object }.last
    end
    private_class_method :handler_for
  end
end
