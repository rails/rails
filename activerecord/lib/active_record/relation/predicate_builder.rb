module ActiveRecord
  class PredicateBuilder # :nodoc:
    @handlers = []

    autoload :RelationHandler, 'active_record/relation/predicate_builder/relation_handler'
    autoload :ArrayHandler, 'active_record/relation/predicate_builder/array_handler'

    def initialize(klass, table)
      @klass = klass
      @table = table
    end

    def resolve_column_aliases(hash)
      hash = hash.dup
      hash.keys.grep(Symbol) do |key|
        if klass.attribute_alias? key
          hash[klass.attribute_alias(key)] = hash.delete key
        end
      end
      hash
    end

    def build_from_hash(attributes)
      attributes = convert_dot_notation_to_hash(attributes.stringify_keys)
      expand_from_hash(attributes)
    end

    def expand(column, value)
      queries = []

      # Find the foreign key when using queries such as:
      # Post.where(author: author)
      #
      # For polymorphic relationships, find the foreign key and type:
      # PriceEstimate.where(estimate_of: treasure)
      if klass && reflection = klass._reflect_on_association(column)
        if reflection.polymorphic? && base_class = polymorphic_base_class_from_value(value)
          queries << self.class.build(table[reflection.foreign_type], base_class)
        end

        column = reflection.foreign_key
      end

      queries << self.class.build(table[column], value)
      queries
    end

    def polymorphic_base_class_from_value(value)
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

    def self.handler_for(object)
      @handlers.detect { |klass, _| klass === object }.last
    end
    private_class_method :handler_for

    protected

    attr_reader :klass, :table

    def expand_from_hash(attributes)
      return ["1=0"] if attributes.empty?

      attributes.flat_map do |key, value|
        if value.is_a?(Hash)
          arel_table = Arel::Table.new(key)
          association = klass._reflect_on_association(key)
          builder = self.class.new(association && association.klass, arel_table)

          builder.expand_from_hash(value)
        else
          expand(key, value)
        end
      end
    end

    private

    def convert_dot_notation_to_hash(attributes)
      dot_notation = attributes.keys.select { |s| s.include?(".") }

      dot_notation.each do |key|
        table_name, column_name = key.split(".")
        value = attributes.delete(key)
        attributes[table_name] ||= {}

        attributes[table_name] = attributes[table_name].merge(column_name => value)
      end

      attributes
    end
  end
end
