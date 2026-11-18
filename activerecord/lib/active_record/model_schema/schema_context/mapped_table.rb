# frozen_string_literal: true

module ActiveRecord
  module ModelSchema
    class SchemaContext # :nodoc:
      class MappedTable # :nodoc:
        attr_reader :primary_key_definition, :_primary_key, :_primary_key_definition,
          :columns_hash, :columns, :column_names, :content_columns,
          :query_constraints_list, :composite_query_constraints_list,
          :composite_query_constraints_definition, :timestamp_attributes_for_create_in_model,
          :timestamp_attributes_for_update_in_model, :all_timestamp_attributes_in_model

        attr_accessor :attributes

        def initialize(context)
          columns_hash = context.schema_cache.columns_hash(context.table_name)
          if context.only_columns.present?
            columns_hash = columns_hash.slice(*context.only_columns)
          elsif context.ignored_columns.present?
            columns_hash = columns_hash.except(*context.ignored_columns)
          end
          @columns_hash = columns_hash.freeze
          @columns = @columns_hash.values.freeze
          @column_names = @columns.map(&:name).freeze
        end

        def _returning_columns_for_insert(connection)
          auto_populated_columns = @columns.filter_map do |c|
            -c.name if connection.return_value_after_insert?(c)
          end

          (auto_populated_columns.empty? ? primary_key_definition.columns : auto_populated_columns).freeze
        end

        def _returning_columns_for_update(connection)
          @columns.filter_map do |c|
            c.name if connection.return_value_after_update?(c)
          end.freeze
        end

        def resolve_model_hooks(context)
          model_class = context.model_class
          @_primary_key_definition = context.resolve_primary_key_definition
          @_primary_key = @_primary_key_definition.name
          @primary_key_definition = context.apply_primary_key_override(@_primary_key_definition)

          primary_key = @primary_key_definition.name
          @query_constraints_list = context.query_constraints_definition ||
            context.derive_query_constraints_list(primary_key)
          @composite_query_constraints_list = (@query_constraints_list || @primary_key_definition.columns).freeze
          @composite_query_constraints_definition = ActiveRecord::Key.for(@composite_query_constraints_list)
          inheritance_column = model_class.inheritance_column
          @content_columns = @columns.reject do |column|
            @primary_key_definition.include?(column.name) ||
              column.name == inheritance_column ||
              column.name.end_with?("_id", "_count")
          end.freeze
          @has_inheritance_column = @columns_hash.key?(inheritance_column)

          @timestamp_attributes_for_create_in_model = (model_class.timestamp_attributes_for_create & @column_names).freeze
          @timestamp_attributes_for_update_in_model = (model_class.timestamp_attributes_for_update & @column_names).freeze
          @all_timestamp_attributes_in_model = (@timestamp_attributes_for_create_in_model + @timestamp_attributes_for_update_in_model).freeze
        end

        def has_inheritance_column?
          @has_inheritance_column
        end
      end
    end
  end
end
