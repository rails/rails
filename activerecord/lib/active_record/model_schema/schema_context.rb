# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ModelSchema
    # SchemaContext owns all schema-derived state for a model: columns,
    # attribute types, column defaults, and query constraints.
    class SchemaContext # :nodoc:
      # The attributes that records loaded from the database fall back to
      # defaults for when the row doesn't have them: the primary key, and
      # attributes that aren't database columns. Other missing columns stay
      # uninitialized.
      class DatabaseDefaultKeys # :nodoc:
        def initialize(primary_key, columns_hash)
          @primary_key = primary_key
          @columns_hash = columns_hash
        end

        def include?(name)
          @primary_key.include?(name) || !@columns_hash.key?(name)
        end
      end

      # Attributes owns a model's attribute-derived state: attribute
      # defaults, attribute types, and column defaults.
      class Attributes # :nodoc:
        attr_reader :context, :defaults, :types, :builder

        # Built up front, since shareable instances are frozen along with
        # their context.
        def initialize(context, defaults)
          @context = context
          @defaults = defaults
          @types = defaults.cast_types.tap do |hash|
            hash.default = ActiveModel::Type.default_value
          end
          default_keys = DatabaseDefaultKeys.new(context.model_class.primary_key_definition, context.columns_hash)
          @builder = ActiveModel::AttributeSet::Builder.new(@types, defaults, default_keys)
          @column_defaults = defaults.to_hash.freeze if defaults.read_only?
        end

        # Lazy otherwise, since evaluating them calls proc defaults.
        def column_defaults
          @column_defaults ||= defaults.deep_dup.to_hash.freeze
        end
      end

      attr_reader :model_class, :columns_hash, :columns, :column_names,
                  :content_columns, :query_constraints_list,
                  :composite_query_constraints_list, :composite_query_constraints_definition

      attr_reader :timestamp_attributes_for_create_in_model,
        :timestamp_attributes_for_update_in_model,
        :all_timestamp_attributes_in_model

      def initialize(model_class)
        @model_class = model_class
        @attributes = nil
        @schema_loaded = false
        @attributes_key = :"active_record_schema_attributes_#{object_id}"
      end

      def attributes
        # Fast path: shareable attributes built with the schema. Otherwise
        # each Ractor builds its own.
        @attributes || (ActiveSupport::Ractors[@attributes_key] ||= Attributes.new(self, build_default_attributes))
      end

      def table_name
        model_class.table_name
      end

      def primary_key
        model_class.primary_key
      end

      def has_query_constraints?
        !!query_constraints
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

      # The model's columns as attributes, with its attribute declarations
      # applied. Read only unless some default can't be frozen.
      def build_default_attributes # :nodoc:
        attributes = model_class.columns_hash.transform_values do |column|
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
        columns_hash = model_class.columns_hash
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

        primary_key = self.primary_key
        @query_constraints_list = query_constraints || derive_query_constraints_list(primary_key)
        @composite_query_constraints_list = (@query_constraints_list || Array(primary_key)).freeze
        @composite_query_constraints_definition = ActiveRecord::Key.for(@composite_query_constraints_list)

        @content_columns = @columns.reject do |c|
          Array(primary_key).include?(c.name) ||
          c.name == model_class.inheritance_column ||
          c.name.end_with?("_id", "_count")
        end.freeze

        @timestamp_attributes_for_create_in_model = (model_class.timestamp_attributes_for_create & @column_names).freeze
        @timestamp_attributes_for_update_in_model = (model_class.timestamp_attributes_for_update & @column_names).freeze
        @all_timestamp_attributes_in_model = (@timestamp_attributes_for_create_in_model + @timestamp_attributes_for_update_in_model).freeze

        model_class.make_pending_attribute_modifications_shareable
        default_attributes = build_default_attributes
        attributes = Attributes.new(self, default_attributes)
        if default_attributes.read_only? && ActiveSupport::Ractors.shareable?(default_attributes)
          @attributes = attributes
        else
          # Slow path: this context is made shareable after loading, and that
          # must not freeze these defaults, so only this Ractor gets them.
          ActiveSupport::Ractors[@attributes_key] = attributes
        end

        @schema_loaded = true
      end

      private
        def derive_query_constraints_list(primary_key)
          if model_class.base_class? || primary_key != model_class.base_class.primary_key
            primary_key if primary_key.is_a?(Array)
          else
            model_class.base_class.query_constraints_definition || (primary_key if primary_key.is_a?(Array))
          end
        end

        def query_constraints
          model_class.query_constraints_definition
        end
    end
  end
end
