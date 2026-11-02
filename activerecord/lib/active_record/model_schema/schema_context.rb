# frozen_string_literal: true

require "active_record/model_schema/schema_context/mapped_table"
require "active_record/model_schema/schema_context/attributes"

module ActiveRecord
  module ModelSchema
    class SchemaContext # :nodoc:
      attr_reader :model_class, :table_name, :only_columns, :ignored_columns, :query_constraints_definition

      def initialize(model_class)
        @model_class = model_class
        @table_name = model_class.table_name
        @only_columns = model_class.only_columns
        @ignored_columns = model_class.ignored_columns
        @query_constraints_definition = model_class.query_constraints_definition
        @mapped_table_cell = ActiveSupport::Ractors::Cell.new
        @attributes_key = :"active_record_schema_attributes_#{model_class.object_id}"
      end

      def attributes
        # Read-only defaults are shared through the mapped table; otherwise
        # each Ractor builds its own.
        mapped_table.attributes || ractor_attributes
      end

      def ractor_attributes # :nodoc:
        slot = ActiveSupport::Ractors[@attributes_key]
        return slot[1] if slot && slot[0].equal?(self)

        attributes = Attributes.new(mapped_table, build_default_attributes)
        ActiveSupport::Ractors[@attributes_key] = [self, attributes].freeze
        attributes
      end

      def derive_query_constraints_list(primary_key)
        if model_class.base_class? || primary_key != model_class.base_class.primary_key
          primary_key if primary_key.is_a?(Array)
        else
          model_class.base_class.query_constraints_definition || (primary_key if primary_key.is_a?(Array))
        end
      end

      def primary_key
        model_class.primary_key
      end

      def schema_cache
        model_class.schema_cache
      end

      def table_exists?
        table_name && schema_cache.data_source_exists?(table_name)
      end

      def has_query_constraints?
        !!query_constraints_definition
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

      def loaded_mapped_table # :nodoc:
        @mapped_table_cell.value
      end

      def schema_loaded?
        !loaded_mapped_table.nil?
      end

      # The model's columns as attributes, with its attribute declarations
      # applied. Read only unless some default can't be frozen.
      def build_default_attributes # :nodoc:
        attributes = mapped_table.columns_hash.transform_values do |column|
          ActiveModel::Attribute.from_database(column.name, column.default, model_class.type_for_column(column))
        end
        model_class.apply_pending_attribute_modifications(attributes)

        if attributes.each_value.all?(&:freezable?)
          attributes.each_value(&:freeze)
          ActiveModel::ReadOnlyAttributeSet.new(attributes.freeze)
        else
          ActiveModel::AttributeSet.new(attributes)
        end
      end

      def load_schema!
        unless table_name
          raise ActiveRecord::TableNotSpecified, "#{model_class} has no table configured. Set one with #{model_class}.table_name="
        end

        mapped_table = MappedTable.new(self)
        # An inheritance_column override can call columns_hash, so we make
        # this table available to reentrant reads before invoking model hooks.
        yield mapped_table
        mapped_table.resolve_model_hooks(self)
        model_class.make_pending_attribute_modifications_shareable
        attributes = Attributes.new(mapped_table, build_default_attributes)
        if attributes.defaults.read_only? && ActiveSupport::Ractors.shareable?(attributes.defaults)
          mapped_table.attributes = attributes
        else
          ActiveSupport::Ractors[@attributes_key] = [self, attributes].freeze
        end
        @mapped_table_cell.value = ActiveSupport::Ractors.make_shareable(mapped_table.freeze)
      end

      def mapped_table # :nodoc:
        loaded_mapped_table || ActiveSupport::Ractors.on_main(self) { model_class.load_schema_context(self) }
      end
    end
  end
end
