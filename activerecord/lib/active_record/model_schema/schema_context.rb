# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ModelSchema
    # SchemaContext owns all schema-derived state for a model: columns,
    # attribute types, and column defaults.
    class SchemaContext # :nodoc:
      # Attributes owns a model's attribute-derived state: attribute
      # defaults, attribute types, and column defaults.
      class Attributes # :nodoc:
        attr_reader :context, :defaults

        def initialize(context)
          attribute_set = context.attribute_set
          context.model_class.apply_pending_attribute_modifications(attribute_set)

          @defaults = attribute_set
          @context = context
        end

        def types
          @types ||= defaults.cast_types.tap do |hash|
            hash.default = ActiveModel::Type.default_value
          end
        end

        def builder
          primary_key_defaults = defaults.except(*(context.model_class.column_names - Array(context.model_class.primary_key)))
          ActiveModel::AttributeSet::Builder.new(types, primary_key_defaults)
        end

        def column_defaults
          @column_defaults ||= defaults.deep_dup.to_hash.freeze
        end
      end

      attr_reader :model_class, :columns_hash, :columns, :column_names,
                  :content_columns

      def initialize(model_class)
        @model_class = model_class
        @schema_loaded = false
        @attributes_key = :"active_record_schema_attributes_#{object_id}"
      end

      def attributes
        ActiveSupport::Ractors[@attributes_key] ||= Attributes.new(self)
      end

      def table_name
        model_class.table_name
      end

      def primary_key
        model_class.primary_key
      end

      def _returning_columns_for_insert(connection)
        auto_populated_columns = columns.filter_map do |c|
          -c.name if connection.return_value_after_insert?(c)
        end

        (auto_populated_columns.empty? ? Array(primary_key) : auto_populated_columns).freeze
      end

      def _returning_columns_for_update(connection)
        columns.filter_map do |c|
          c.name if connection.return_value_after_update?(c)
        end.freeze
      end

      def cached_find_by_statement(connection, key, &block) # :nodoc:
        cache = find_by_statement_cache[connection.prepared_statements]
        cache.compute_if_absent(key) { StatementCache.create(connection, &block) }
      end

      def initialize_find_by_cache # :nodoc:
        ActiveSupport::Ractors[model_class.find_by_statement_cache_key] = { true => Concurrent::Map.new, false => Concurrent::Map.new }
      end

      def find_by_statement_cache # :nodoc:
        ActiveSupport::Ractors[model_class.find_by_statement_cache_key] || initialize_find_by_cache
      end

      def schema_loaded?
        @schema_loaded
      end

      def attribute_set
        attributes_hash = model_class.columns_hash.transform_values do |column|
          ActiveModel::Attribute.from_database(column.name, column.default, model_class.type_for_column(column))
        end
        ActiveModel::AttributeSet.new(attributes_hash)
      end

      def freeze
        load_schema!
        super
      end

      def load_schema!
        return if @schema_loaded

        unless table_name
          raise ActiveRecord::TableNotSpecified, "#{model_class} has no table configured. Set one with #{model_class}.table_name="
        end

        columns_hash = model_class.connection_pool.schema_cache.columns_hash(table_name)
        if model_class.only_columns.present?
          columns_hash = columns_hash.slice(*model_class.only_columns)
        elsif model_class.ignored_columns.present?
          columns_hash = columns_hash.except(*model_class.ignored_columns)
        end
        @columns_hash = columns_hash.freeze

        @columns = @columns_hash.values.freeze
        @column_names = @columns.map(&:name).freeze

        @content_columns = @columns.reject do |c|
          Array(primary_key).include?(c.name) ||
          c.name == model_class.inheritance_column ||
          c.name.end_with?("_id", "_count")
        end.freeze

        model_class.make_pending_attribute_modifications_shareable
        attributes

        @schema_loaded = true
      end
    end
  end
end
