module ActiveRecord
  class PredicateBuilder # :nodoc:
    require "active_record/relation/predicate_builder/array_handler"
    require "active_record/relation/predicate_builder/association_query_handler"
    require "active_record/relation/predicate_builder/base_handler"
    require "active_record/relation/predicate_builder/basic_object_handler"
    require "active_record/relation/predicate_builder/class_handler"
    require "active_record/relation/predicate_builder/polymorphic_array_handler"
    require "active_record/relation/predicate_builder/range_handler"
    require "active_record/relation/predicate_builder/relation_handler"

    delegate :resolve_column_aliases, to: :table

    def initialize(table)
      @table = table
      @handlers = []

      register_handler(BasicObject, BasicObjectHandler.new)
      register_handler(Class, ClassHandler.new(self))
      register_handler(Base, BaseHandler.new(self))
      register_handler(Range, RangeHandler.new)
      register_handler(RangeHandler::RangeWithBinds, RangeHandler.new)
      register_handler(Relation, RelationHandler.new)
      register_handler(Array, ArrayHandler.new(self))
      register_handler(AssociationQueryValue, AssociationQueryHandler.new(self))
      register_handler(PolymorphicArrayValue, PolymorphicArrayHandler.new(self))
    end

    def build_from_hash(attributes)
      attributes = convert_dot_notation_to_hash(attributes)
      expand_from_hash(attributes)
    end

    def create_binds(attributes)
      attributes = convert_dot_notation_to_hash(attributes)
      create_binds_for_hash(attributes)
    end

    def self.references(attributes)
      attributes.map do |key, value|
        if value.is_a?(Hash)
          key
        else
          key = key.to_s
          key.split(".".freeze).first if key.include?(".".freeze)
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
    #     ActiveRecord::PredicateBuilder.new("users").register_handler(MyCustomDateRange, handler)
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
            associated_predicate_builder(key).expand_from_hash(value)
          else
            expand(key, value)
          end
        end
      end

      def create_binds_for_hash(attributes)
        result = attributes.dup
        binds = []

        attributes.each do |column_name, value|
          case value
          when Hash
            attrs, bvs = associated_predicate_builder(column_name).create_binds_for_hash(value)
            result[column_name] = attrs
            binds += bvs
          when Relation
            binds += value.bound_attributes
          when Range
            first = value.begin
            last = value.end
            unless first.respond_to?(:infinite?) && first.infinite?
              binds << build_bind_param(column_name, first)
              first = Arel::Nodes::BindParam.new
            end
            unless last.respond_to?(:infinite?) && last.infinite?
              binds << build_bind_param(column_name, last)
              last = Arel::Nodes::BindParam.new
            end

            result[column_name] = RangeHandler::RangeWithBinds.new(first, last, value.exclude_end?)
          else
            if can_be_bound?(column_name, value)
              result[column_name] = Arel::Nodes::BindParam.new
              binds << build_bind_param(column_name, value)
            end
          end
        end

        [result, binds]
      end

    private

      def expand(column, value)
        # Find the foreign key when using queries such as:
        # Post.where(author: author)
        #
        # For polymorphic relationships, find the foreign key and type:
        # PriceEstimate.where(estimate_of: treasure)
        value = AssociationQueryHandler.value_for(table, column, value) if table.associated_with?(column)
        build(table.arel_attribute(column), value)
      end

      def associated_predicate_builder(association_name)
        self.class.new(table.associated_table(association_name))
      end

      def convert_dot_notation_to_hash(attributes)
        dot_notation = attributes.select do |k, v|
          k.include?(".".freeze) && !v.is_a?(Hash)
        end

        dot_notation.each_key do |key|
          table_name, column_name = key.split(".".freeze)
          value = attributes.delete(key)
          attributes[table_name] ||= {}

          attributes[table_name] = attributes[table_name].merge(column_name => value)
        end

        attributes
      end

      def handler_for(object)
        @handlers.detect { |klass, _| klass === object }.last
      end

      def can_be_bound?(column_name, value)
        !value.nil? &&
          handler_for(value).is_a?(BasicObjectHandler) &&
          !table.associated_with?(column_name)
      end

      def build_bind_param(column_name, value)
        Relation::QueryAttribute.new(column_name.to_s, value, table.type(column_name))
      end
  end
end
