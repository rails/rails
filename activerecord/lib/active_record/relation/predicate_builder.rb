module ActiveRecord
  class PredicateBuilder # :nodoc:
    require "active_record/relation/predicate_builder/association_query_handler"
    require "active_record/relation/predicate_builder/basic_object_handler"
    require "active_record/relation/predicate_builder/polymorphic_array_handler"
    require "active_record/relation/predicate_builder/range_handler"
    require "active_record/relation/predicate_builder/relation_handler"

    delegate :resolve_column_aliases, to: :table

    def initialize(table)
      @table = table
      @handlers = []

      register_handler(BasicObject, BasicObjectHandler.new)
      register_handler(Range, RangeHandler.new)
      register_handler(RangeHandler::RangeWithBinds, RangeHandler.new)
      register_handler(Relation, RelationHandler.new)
    end

    def build_for_hash(attributes)
      attributes = convert_dot_notation_to_hash(attributes)
      build_from_hash(attributes)
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

    # TODO Change this to private once we've dropped Ruby 2.2 support.
    # Workaround for Ruby 2.2 "private attribute?" warning.
    protected

      attr_reader :table

      def build_from_hash(attributes)
        return [["1=0"], []] if attributes.empty?

        parts, binds = [], []
        attributes.each do |column_name, value|
          case
          when value.is_a?(Hash) && !table.has_column?(column_name)
            prts, bvs = associated_predicate_builder(column_name).build_from_hash(value)
            parts.concat(prts)
            binds.concat(bvs)
            next
          when table.associated_with?(column_name)
            # Find the foreign key when using queries such as:
            # Post.where(author: author)
            #
            # For polymorphic relationships, find the foreign key and type:
            # PriceEstimate.where(estimate_of: treasure)
            prts, bvs = build_for_association_query(column_name, value)
            parts.concat(prts)
            binds.concat(bvs)
            next
          when value.is_a?(Array) && !table.type(column_name).respond_to?(:subtype)
            prts, bvs = build_for_array(column_name, value)
            parts.concat(prts)
            binds.concat(bvs)
            next
          when value.is_a?(Relation)
            binds.concat(value.bound_attributes)
          when value.is_a?(Range) && !table.type(column_name).respond_to?(:subtype)
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

            value = RangeHandler::RangeWithBinds.new(first, last, value.exclude_end?)
          when can_be_bound?(column_name, value.is_a?(Base) ? value = value.id : value)
            binds << build_bind_param(column_name, value)
            value = Arel::Nodes::BindParam.new
          end

          parts << build(table.arel_attribute(column_name), value)
        end

        [parts, binds]
      end

      def build_for_association_query(column_name, value)
        parts, binds = [], []
        AssociationQueryValue.queries_for(table, column_name, value).each do |query|
          prts, bvs = build_from_hash(query)
          parts << prts
          binds.concat(bvs)
        end

        if parts.size > 1
          parts = [parts.map { |type, id| Arel::Nodes::Grouping.new(type.and(id)) }.inject(&:or)]
        else
          parts.flatten!
        end

        [parts, binds]
      end

      def build_for_array(column_name, value)
        return [["1=0"], []] if value.empty?
        return build_from_hash(column_name => value.first) if value.size == 1

        parts, binds = [], []
        values, nils = [], false

        value.each do |v|
          case v
          when Range, Relation
            prts, bvs = build_from_hash(column_name => v)
            parts.concat(prts)
            binds.concat(bvs)
          else
            v = v.id if v.is_a?(Base)
            if v.nil?
              nils = true
            else
              values << v
            end
          end
        end

        if values.size == 1
          prts, bvs = build_from_hash(column_name => values.first)
          parts.concat(prts)
          binds.concat(bvs)
        elsif values.size > 1
          parts << table.arel_attribute(column_name).in(values)
        end

        if nils
          parts << table.arel_attribute(column_name).eq(nil)
        end

        if parts.size > 1
          parts = [parts.inject(&:or)]
        end

        [parts, binds]
      end

    private

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
        case value
        when Array, Range
          table.type(column_name).respond_to?(:subtype)
        else
          !value.nil? && handler_for(value).is_a?(BasicObjectHandler)
        end
      end

      def build_bind_param(column_name, value)
        Relation::QueryAttribute.new(column_name.to_s, value, table.type(column_name))
      end
  end
end
