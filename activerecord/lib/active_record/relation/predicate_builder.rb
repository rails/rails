module ActiveRecord
  class PredicateBuilder # :nodoc:
    require 'active_record/relation/predicate_builder/array_handler'
    require 'active_record/relation/predicate_builder/association_query_handler'
    require 'active_record/relation/predicate_builder/base_handler'
    require 'active_record/relation/predicate_builder/basic_object_handler'
    require 'active_record/relation/predicate_builder/class_handler'
    require 'active_record/relation/predicate_builder/range_handler'
    require 'active_record/relation/predicate_builder/relation_handler'

    delegate :resolve_column_aliases, to: :table

    def initialize(table)
      @table = table
      @handlers = []

      register_handler(BasicObject, BasicObjectHandler.new(self))
      register_handler(Class, ClassHandler.new(self))
      register_handler(Base, BaseHandler.new(self))
      register_handler(Range, RangeHandler.new(self))
      register_handler(Relation, RelationHandler.new)
      register_handler(Array, ArrayHandler.new(self))
      register_handler(AssociationQueryValue, AssociationQueryHandler.new(self))
    end

    def build_from_hash(attributes)
      attributes = convert_dot_notation_to_hash(attributes.stringify_keys)
      expand_from_hash(attributes)
    end

    def expand(column, value)
      # Find the foreign key when using queries such as:
      # Post.where(author: author)
      #
      # For polymorphic relationships, find the foreign key and type:
      # PriceEstimate.where(estimate_of: treasure)
      if table.associated_with?(column)
        value = AssociationQueryValue.new(table.associated_table(column), value)
      end

      build(table.arel_attribute(column), value)
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
    def register_handler(klass, handler)
      @handlers.unshift([klass, handler])
    end

    def build(attribute, value)
      handler_for(value).call(attribute, value)
    end

    protected

    attr_reader :table

    def expand_from_hash(attributes)
      return ["1=0"] if attributes.empty?

      attributes.flat_map do |key, value|
        if value.is_a?(Hash)
          builder = self.class.new(table.associated_table(key))
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

    def handler_for(object)
      @handlers.detect { |klass, _| klass === object }.last
    end
  end
end
