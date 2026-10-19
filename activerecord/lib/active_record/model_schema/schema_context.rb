# frozen_string_literal: true

require "active_record/model_schema/schema_context/mapped_table"
require "active_record/model_schema/schema_context/attributes"

module ActiveRecord
  module ModelSchema
    class SchemaContext # :nodoc:
      attr_reader :model_class, :table_name, :only_columns, :ignored_columns, :base_context,
        :query_constraints_definition, :configured_primary_key_definition

      def initialize(model_class)
        @model_class = model_class
        unless model_class.base_class?
          base_class = model_class.base_class
          @base_primary_key_definition = base_class.configured_primary_key_definition
          @base_query_constraints_definition = base_class.query_constraints_definition
          @base_context = base_class.schema_context unless @base_primary_key_definition
        end
        @table_name = model_class.table_name
        @only_columns = model_class.only_columns
        @ignored_columns = model_class.ignored_columns
        @query_constraints_definition = model_class.query_constraints_definition
        @configured_primary_key_definition = model_class.configured_primary_key_definition
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
        if model_class.base_class? || primary_key != base_primary_key
          primary_key if primary_key.is_a?(Array)
        else
          @base_query_constraints_definition || (primary_key if primary_key.is_a?(Array))
        end
      end

      def primary_key
        primary_key_definition.name
      end

      def primary_key_definition
        if definition = configured_primary_key_definition
          definition
        elsif table = loaded_mapped_table
          table._primary_key_definition
        else
          ActiveSupport::Ractors.on_main(self) do
            if table_exists?
              mapped_table._primary_key_definition
            else
              resolve_primary_key_definition
            end
          end
        end
      end

      def resolve_primary_key_definition # :nodoc:
        configured_primary_key_definition || base_context&.primary_key_definition ||
          ActiveRecord::Key.for(inferred_primary_key)
      end

      def apply_primary_key_override(definition) # :nodoc:
        if current? && overridden_primary_key?(model_class)
          ActiveRecord::Key.for(model_class.primary_key)
        else
          definition
        end
      end

      def current?
        model_class.current_schema_context.equal?(self)
      end

      def schema_cache
        model_class.schema_cache
      end

      def table_exists?
        table_name && schema_cache.data_source_exists?(table_name)
      end

      def inferred_primary_key
        if table_exists?
          schema_cache.primary_keys(table_name)
        else
          "id"
        end
      end

      def has_query_constraints?
        !!query_constraints_definition
      end

      def cached_find_by_statement(connection, key, &block) # :nodoc:
        cache = find_by_statement_cache[connection.prepared_statements]
        cache.compute_if_absent(key) { StatementCache.create(connection, &block) }
      end

      def find_by_statement_cache # :nodoc:
        statements = ActiveSupport::Ractors[model_class.find_by_statement_cache_key] || model_class.initialize_find_by_cache
        statements.fetch_or_store(self) { { true => Concurrent::Map.new, false => Concurrent::Map.new } }
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
        attributes = index_default_attributes(attributes)

        if attributes.each_value.all?(&:freezable?)
          attributes.each_value(&:freeze)
          ActiveModel::ReadOnlyAttributeSet.new(attributes.freeze)
        else
          ActiveModel::AttributeSet.new(attributes)
        end
      end

      # Lays +attributes+ out by each column's slot, so they can be read by
      # index. Attributes without a column (or whose column has no slot, as
      # with adapters that don't set it) go after the last column. The
      # indexes are Integers rather than columns, so they can be shared
      # between Ractors.
      def index_default_attributes(attributes) # :nodoc:
        columns_hash = mapped_table.columns_hash
        last_slot = columns_hash.each_value.filter_map(&:slot).max || -1
        indexes = attributes.each_key.to_h do |name|
          column = columns_hash[name]
          [name, column&.slot || (last_slot += 1)]
        end.freeze
        indexes = inherited_indexes(indexes)

        row = ActiveModel::IndexedRow.unset_row(last_slot + 1)
        attributes.each { |name, attribute| row[indexes[name]] = attribute }
        ActiveModel::IndexedRow::Mutable.new(indexes, row)
      end

      # An STI subclass that doesn't change its parent's layout shares the
      # parent's indexes, so rows laid out for the parent can be checked with
      # +equal?+ (see ActiveModel::AttributeSet::Builder#relayout).
      def inherited_indexes(indexes) # :nodoc:
        return indexes if model_class.base_class?

        parent_indexes = model_class.superclass.attributes_builder.indexes
        parent_indexes == indexes ? parent_indexes : indexes
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
        model_class.include(AttributeMethods::CompositePrimaryKey) if mapped_table.primary_key_definition.composite?
        @mapped_table_cell.value = ActiveSupport::Ractors.make_shareable(mapped_table.freeze)
      end

      def mapped_table # :nodoc:
        loaded_mapped_table || ActiveSupport::Ractors.on_main(self) { model_class.load_schema_context(self) }
      end

      private
        def base_primary_key
          base_class = model_class.base_class
          if current? && overridden_primary_key?(base_class)
            base_class.primary_key
          else
            (@base_primary_key_definition || base_context.primary_key_definition).name
          end
        end

        def overridden_primary_key?(model)
          model.method(:primary_key).owner != AttributeMethods::PrimaryKey::ClassMethods
        end
    end
  end
end
