# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ModelSchema
    # SchemaContext owns all schema-derived state for a model: columns,
    # attribute types, column defaults, and query constraints.
    class SchemaContext # :nodoc:
      attr_reader :model_class, :columns_hash, :columns, :column_names,
                  :attribute_types, :content_columns

      def initialize(model_class, query_constraints_list: nil)
        @model_class = model_class
        @explicit_query_constraints_list = query_constraints_list&.map { |column| -column.to_s }.freeze
        @has_query_constraints = @explicit_query_constraints_list
        @query_constraints_list = @explicit_query_constraints_list if @explicit_query_constraints_list
        @schema_loaded = false
        @schema_loading = false
      end

      def table_name
        model_class.table_name
      end

      def primary_key
        model_class.primary_key
      end

      def _default_attributes
        @default_attributes
      end

      def attributes_builder
        defaults = _default_attributes.except(*(column_names - Array(primary_key)))
        ActiveModel::AttributeSet::Builder.new(attribute_types, defaults)
      end

      def column_defaults
        @column_defaults ||= _default_attributes.deep_dup.to_hash.freeze
      end

      def _returning_columns_for_insert(connection)
        @_returning_columns_for_insert || ActiveSupport::Ractors.on_main(self) do
          @_returning_columns_for_insert ||= begin
            auto_populated_columns = columns.filter_map do |c|
              -c.name if connection.return_value_after_insert?(c)
            end

            (auto_populated_columns.empty? ? Array(primary_key) : auto_populated_columns).freeze
          end
        end
      end

      def _returning_columns_for_update(connection)
        @_returning_columns_for_update ||= columns.filter_map do |c|
          c.name if connection.return_value_after_update?(c)
        end
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

      def schema_loading?
        @schema_loading
      end

      def has_query_constraints?
        @has_query_constraints
      end

      def query_constraints_list
        return @query_constraints_list if defined?(@query_constraints_list)

        @query_constraints_list =
          if model_class.base_class? || primary_key != model_class.base_class.primary_key
            primary_key if primary_key.is_a?(Array)
          else
            model_class.base_class.query_constraints_list
          end
      end

      def composite_query_constraints_list
        @composite_query_constraints_list ||= query_constraints_list || Array(primary_key).freeze
      end

      def load_schema!
        return if @schema_loaded
        @schema_loading = true

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

        @default_attributes = begin
          attributes_hash = @columns_hash.transform_values do |column|
            ActiveModel::Attribute.from_database(column.name, column.default, model_class.type_for_column(column))
          end

          attribute_set = ActiveModel::AttributeSet.new(attributes_hash)
          model_class.apply_pending_attribute_modifications(attribute_set)
          attribute_set
        end

        @attribute_types = @default_attributes.cast_types.tap do |hash|
          hash.default = ActiveModel::Type.default_value
        end

        query_constraints_list
        composite_query_constraints_list

        @content_columns = @columns.reject do |c|
          Array(primary_key).include?(c.name) ||
          c.name == model_class.inheritance_column ||
          c.name.end_with?("_id", "_count")
        end.freeze

        @schema_loaded = true
      ensure
        @schema_loading = false
      end
    end
  end
end
