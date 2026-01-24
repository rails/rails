# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder # :nodoc:
    require "active_record/relation/predicate_builder/array_handler"
    require "active_record/relation/predicate_builder/basic_object_handler"
    require "active_record/relation/predicate_builder/range_handler"
    require "active_record/relation/predicate_builder/relation_handler"
    require "active_record/relation/predicate_builder/association_query_value"
    require "active_record/relation/predicate_builder/polymorphic_array_value"

    def initialize(table)
      @table = table
      @handlers = []

      register_handler(BasicObject, BasicObjectHandler.new(self))
      register_handler(Range, RangeHandler.new(self))
      register_handler(Relation, RelationHandler.new)
      register_handler(Array, ArrayHandler.new(self))
      register_handler(Set, ArrayHandler.new(self))
    end

    def build_from_hash(attributes, &block)
      attributes = convert_dot_notation_to_hash(attributes)
      expand_from_hash(attributes, &block)
    end

    def self.references(attributes)
      attributes.each_with_object([]) do |(key, value), result|
        if value.is_a?(Hash)
          result << Arel.sql(key, retryable: true)
        elsif (idx = key.rindex("."))
          result << Arel.sql(key[0, idx], retryable: true)
        end
      end
    end

    # Define how a class is converted to Arel nodes when passed to +where+.
    # The handler can be any object that responds to +call+, and will be used
    # for any value that <tt>===</tt> the class given. For example:
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

    def [](attr_name, value, operator = nil)
      build(table.arel_table[attr_name], value, operator)
    end

    def build(attribute, value, operator = nil)
      value = value.id if value.respond_to?(:id)
      if operator ||= table.type(attribute.name).force_equality?(value) && :eq
        bind = build_bind_attribute(attribute.name, value)
        attribute.public_send(operator, bind)
      else
        handler_for(value).call(attribute, value)
      end
    end

    def build_bind_attribute(column_name, value)
      Relation::QueryAttribute.new(column_name, value, table.type(column_name))
    end

    def resolve_arel_attribute(table_name, column_name, &block)
      table.associated_table(table_name, &block).arel_table[column_name]
    end

    def with(table)
      other = dup
      other.table = table
      other
    end

    protected
      attr_writer :table

      def expand_from_hash(attributes, &block)
        return [Arel.sql("1=0", retryable: true)] if attributes.empty?

        attributes.flat_map do |key, value|
          if key.is_a?(Array) && key.size == 1
            key = key.first
            value = value.flatten
          end

          if key.is_a?(Array)
            queries = Array(value).map do |ids_set|
              raise ArgumentError, "Expected corresponding value for #{key} to be an Array" unless ids_set.is_a?(Array)
              expand_from_hash(key.zip(ids_set).to_h)
            end
            grouping_queries(queries)
          elsif value.is_a?(Hash) && !table.has_column?(key)
            table.associated_table(key, &block)
              .predicate_builder.expand_from_hash(value.stringify_keys)
          elsif (associated_reflection = table.associated_with(key))
            # Find the foreign key when using queries such as:
            # Post.where(author: author)
            #
            # For polymorphic relationships, find the foreign key and type:
            # PriceEstimate.where(estimate_of: treasure)

            if associated_reflection.polymorphic?
              value = [value] unless value.is_a?(Array)
              klass = PolymorphicArrayValue
            elsif associated_reflection.through_reflection?
              associated_table = table.associated_table(key)

              next associated_table.predicate_builder.expand_from_hash(
                associated_table.primary_key => value
              )
            end

            klass ||= AssociationQueryValue
            queries = klass.new(associated_reflection, value).queries.map! do |query|
              # If the query produced is identical to attributes don't go any deeper.
              # Prevents stack level too deep errors when association and foreign_key are identical.
              query == attributes ? self[key, value] : expand_from_hash(query)
            end

            grouping_queries(queries)
          elsif table.aggregated_with?(key)
            mapping = table.reflect_on_aggregation(key).mapping
            values = value.nil? ? [nil] : Array.wrap(value)
            if mapping.length == 1 || values.empty?
              column_name, aggr_attr = mapping.first
              values = values.map do |object|
                object.respond_to?(aggr_attr) ? object.public_send(aggr_attr) : object
              end
              self[column_name, values]
            else
              queries = values.map do |object|
                mapping.map do |field_attr, aggregate_attr|
                  self[field_attr, object.try!(aggregate_attr)]
                end
              end

              grouping_queries(queries)
            end
          else
            self[key, value]
          end
        end
      end

    private
      attr_reader :table

      def grouping_queries(queries)
        if queries.one?
          queries.first
        else
          queries.map! { |query| query.reduce(&:and) }
          queries = Arel::Nodes::Or.new(queries)
          Arel::Nodes::Grouping.new(queries)
        end
      end

      def convert_dot_notation_to_hash(attributes)
        attributes.each_with_object({}) do |(key, value), converted|
          if value.is_a?(Hash)
            if (existing = converted[key])
              existing.merge!(value)
            else
              converted[key] = value.dup
            end
          elsif (idx = key.rindex("."))
            table_name, column_name = key[0, idx], key[idx + 1, key.length]

            if (existing = converted[table_name])
              existing[column_name] = value
            else
              converted[table_name] = { column_name => value }
            end
          else
            converted[key] = value
          end
        end
      end

      def handler_for(object)
        @handlers.detect { |klass, _| klass === object }.last
      end
  end
end
