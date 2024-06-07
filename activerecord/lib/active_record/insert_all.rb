# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  class InsertAll # :nodoc:
    attr_reader :model, :connection, :inserts, :keys
    attr_reader :on_duplicate, :update_only, :returning, :unique_by, :update_sql

    class << self
      def execute(relation, ...)
        relation.model.with_connection do |c|
          new(relation, c, ...).execute
        end
      end
    end

    def initialize(relation, connection, inserts, on_duplicate:, update_only: nil, returning: nil, unique_by: nil, record_timestamps: nil)
      @relation = relation
      @model, @connection, @inserts = relation.model, connection, inserts.map(&:stringify_keys)
      @on_duplicate, @update_only, @returning, @unique_by = on_duplicate, update_only, returning, unique_by
      @record_timestamps = record_timestamps.nil? ? model.record_timestamps : record_timestamps

      disallow_raw_sql!(on_duplicate)
      disallow_raw_sql!(returning)

      if @inserts.empty?
        @keys = []
      else
        resolve_sti
        resolve_attribute_aliases
        @keys = @inserts.first.keys
      end

      @scope_attributes = relation.scope_for_create.except(@model.inheritance_column)
      @keys |= @scope_attributes.keys
      @keys = @keys.to_set

      @returning = (connection.supports_insert_returning? ? primary_keys : false) if @returning.nil?
      @returning = false if @returning == []

      @unique_by = find_unique_index_for(@unique_by)

      configure_on_duplicate_update_logic
      ensure_valid_options_for_connection!
    end

    def execute
      return ActiveRecord::Result.empty if inserts.empty?

      message = +"#{model} "
      message << "Bulk " if inserts.many?
      message << (on_duplicate == :update ? "Upsert" : "Insert")
      connection.exec_insert_all to_sql, message
    end

    def updatable_columns
      @updatable_columns ||= keys - readonly_columns - unique_by_columns
    end

    def primary_keys
      Array(@model.schema_cache.primary_keys(model.table_name))
    end

    def skip_duplicates?
      on_duplicate == :skip
    end

    def update_duplicates?
      on_duplicate == :update
    end

    def map_key_with_value
      inserts.map do |attributes|
        attributes = attributes.stringify_keys
        attributes.merge!(@scope_attributes)
        attributes.reverse_merge!(timestamps_for_create) if record_timestamps?

        verify_attributes(attributes)

        keys_including_timestamps.map do |key|
          yield key, attributes[key]
        end
      end
    end

    def record_timestamps?
      @record_timestamps
    end

    # TODO: Consider renaming this method, as it only conditionally extends keys, not always
    def keys_including_timestamps
      @keys_including_timestamps ||= if record_timestamps?
        keys + model.all_timestamp_attributes_in_model
      else
        keys
      end
    end

    private
      def has_attribute_aliases?(attributes)
        attributes.keys.any? { |attribute| model.attribute_alias?(attribute) }
      end

      def resolve_sti
        return if model.descends_from_active_record?

        sti_type = model.sti_name
        @inserts = @inserts.map do |insert|
          insert.reverse_merge(model.inheritance_column.to_s => sti_type)
        end
      end

      def resolve_attribute_aliases
        return unless has_attribute_aliases?(@inserts.first)

        @inserts = @inserts.map do |insert|
          insert.transform_keys { |attribute| resolve_attribute_alias(attribute) }
        end

        @update_only = Array(@update_only).map { |attribute| resolve_attribute_alias(attribute) } if @update_only
        @unique_by = Array(@unique_by).map { |attribute| resolve_attribute_alias(attribute) } if @unique_by
      end

      def resolve_attribute_alias(attribute)
        model.attribute_alias(attribute) || attribute
      end

      def configure_on_duplicate_update_logic
        if custom_update_sql_provided? && update_only.present?
          raise ArgumentError, "You can't set :update_only and provide custom update SQL via :on_duplicate at the same time"
        end

        if update_only.present?
          @updatable_columns = Array(update_only)
          @on_duplicate = :update
        elsif custom_update_sql_provided?
          @update_sql = on_duplicate
          @on_duplicate = :update
        elsif @on_duplicate == :update && updatable_columns.empty?
          @on_duplicate = :skip
        end
      end

      def custom_update_sql_provided?
        @custom_update_sql_provided ||= Arel.arel_node?(on_duplicate)
      end

      def find_unique_index_for(unique_by)
        if !connection.supports_insert_conflict_target?
          return if unique_by.nil?

          raise ArgumentError, "#{connection.class} does not support :unique_by"
        end

        name_or_columns = unique_by || model.primary_key
        match = Array(name_or_columns).map(&:to_s)
        sorted_match = match.sort

        if index = unique_indexes.find { |i| match.include?(i.name) || Array(i.columns).sort == sorted_match }
          index
        elsif match == primary_keys
          unique_by.nil? ? nil : ActiveRecord::ConnectionAdapters::IndexDefinition.new(model.table_name, "#{model.table_name}_primary_key", true, match)
        else
          raise ArgumentError, "No unique index found for #{name_or_columns}"
        end
      end

      def unique_indexes
        @model.schema_cache.indexes(model.table_name).select(&:unique)
      end

      def ensure_valid_options_for_connection!
        if returning && !connection.supports_insert_returning?
          raise ArgumentError, "#{connection.class} does not support :returning"
        end

        if skip_duplicates? && !connection.supports_insert_on_duplicate_skip?
          raise ArgumentError, "#{connection.class} does not support skipping duplicates"
        end

        if update_duplicates? && !connection.supports_insert_on_duplicate_update?
          raise ArgumentError, "#{connection.class} does not support upsert"
        end

        if unique_by && !connection.supports_insert_conflict_target?
          raise ArgumentError, "#{connection.class} does not support :unique_by"
        end
      end


      def to_sql
        connection.build_insert_sql(ActiveRecord::InsertAll::Builder.new(self))
      end


      def readonly_columns
        primary_keys + model.readonly_attributes
      end

      def unique_by_columns
        Array(unique_by&.columns)
      end


      def verify_attributes(attributes)
        if keys_including_timestamps != attributes.keys.to_set
          raise ArgumentError, "All objects being inserted must have the same keys"
        end
      end

      def disallow_raw_sql!(value)
        return if !value.is_a?(String) || Arel.arel_node?(value)

        raise ArgumentError, "Dangerous query method (method whose arguments are used as raw " \
                             "SQL) called: #{value}. " \
                             "Known-safe values can be passed " \
                             "by wrapping them in Arel.sql()."
      end

      def timestamps_for_create
        model.all_timestamp_attributes_in_model.index_with(connection.high_precision_current_timestamp)
      end

      class Builder # :nodoc:
        attr_reader :model

        delegate :skip_duplicates?, :update_duplicates?, :keys, :keys_including_timestamps, :record_timestamps?, to: :insert_all

        def initialize(insert_all)
          @insert_all, @model, @connection = insert_all, insert_all.model, insert_all.connection
        end

        def into
          "INTO #{model.quoted_table_name} (#{columns_list})"
        end

        def values_list
          types = extract_types_from_columns_on(model.table_name, keys: keys_including_timestamps)

          values_list = insert_all.map_key_with_value do |key, value|
            next value if Arel::Nodes::SqlLiteral === value
            connection.with_yaml_fallback(types[key].serialize(value))
          end

          connection.visitor.compile(Arel::Nodes::ValuesList.new(values_list))
        end

        def returning
          return unless insert_all.returning

          if insert_all.returning.is_a?(String)
            insert_all.returning
          else
            Array(insert_all.returning).map do |attribute|
              if model.attribute_alias?(attribute)
                "#{quote_column(model.attribute_alias(attribute))} AS #{quote_column(attribute)}"
              else
                quote_column(attribute)
              end
            end.join(",")
          end
        end

        def conflict_target
          if index = insert_all.unique_by
            sql = +"(#{format_columns(index.columns)})"
            sql << " WHERE #{index.where}" if index.where
            sql
          elsif update_duplicates?
            "(#{format_columns(insert_all.primary_keys)})"
          end
        end

        def updatable_columns
          quote_columns(insert_all.updatable_columns)
        end

        def touch_model_timestamps_unless(&block)
          return "" unless update_duplicates? && record_timestamps?

          model.timestamp_attributes_for_update_in_model.filter_map do |column_name|
            if touch_timestamp_attribute?(column_name)
              "#{column_name}=(CASE WHEN (#{updatable_columns.map(&block).join(" AND ")}) THEN #{model.quoted_table_name}.#{column_name} ELSE #{connection.high_precision_current_timestamp} END),"
            end
          end.join
        end

        def raw_update_sql
          insert_all.update_sql
        end

        alias raw_update_sql? raw_update_sql

        private
          attr_reader :connection, :insert_all

          def touch_timestamp_attribute?(column_name)
            insert_all.updatable_columns.exclude?(column_name)
          end

          def columns_list
            format_columns(insert_all.keys_including_timestamps)
          end

          def extract_types_from_columns_on(table_name, keys:)
            columns = @model.schema_cache.columns_hash(table_name)

            unknown_column = (keys - columns.keys).first
            raise UnknownAttributeError.new(model.new, unknown_column) if unknown_column

            keys.index_with { |key| model.type_for_attribute(key) }
          end

          def format_columns(columns)
            columns.respond_to?(:map) ? quote_columns(columns).join(",") : columns
          end

          def quote_columns(columns)
            columns.map { |column| quote_column(column) }
          end

          def quote_column(column)
            connection.quote_column_name(column)
          end
      end
  end
end
