# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  class UniformUpdateAll # :nodoc:
    attr_reader :model, :connection, :updates, :read_keys, :write_keys

    def initialize(relation, connection, updates, record_timestamps: nil)
      @model, @connection = relation.model, connection
      @updates = normalize_updates(updates)
      @record_timestamps = record_timestamps.nil? ? model.record_timestamps : record_timestamps

      resolve_attribute_aliases
      @read_keys = @updates.first[0].keys.to_set
      @write_keys = @updates.first[1].keys.to_set

      verify_input_keys
    end

    def column_types
      columns_hash = model.columns_hash
      @column_types ||= read_keys.to_a.concat(write_keys.to_a).map! { |key| columns_hash.fetch(key) }
    end

    def build_arel
      types = extract_types_from_columns_on(model.table_name, keys: read_keys | write_keys)

      rows = map_key_with_value do |key, value|
        next value if Arel::Nodes::SqlLiteral === value
        ActiveModel::Type::SerializeCastValue.serialize(type = types[key], type.cast(value))
      end

      values_table = Arel::ValuesTable.new(:__active_record_uua_temp, rows, column_types: column_types)

      join_conditions = read_keys.map.with_index do |key, index|
        model.arel_table[key].eq(values_table[index])
      end
      set_assignments = write_keys.map.with_index do |key, index|
        [model.arel_table[key], values_table[index + read_keys.size]]
      end
      set_assignments += timestamp_assignments(set_assignments) if timestamp_keys.any?

      [values_table, join_conditions, set_assignments]
    end

    private
      def timestamp_assignments(set_assignments)
        case_conditions = set_assignments.map do |left, right|
          left.is_not_distinct_from(right)
        end

        timestamp_keys.map do |key|
          case_assignment = Arel::Nodes::Case.new.when(Arel::Nodes::And.new(case_conditions))
                                             .then(model.arel_table[key])
                                             .else(connection.high_precision_current_timestamp)
          [model.arel_table[key], Arel::Nodes::Grouping.new(case_assignment)]
        end
      end

      def verify_input_keys
        if updates.empty?
          raise ArgumentError, "Empty updates object"
        end
        if read_keys.empty?
          raise ArgumentError, "Empty conditions object"
        end
        if write_keys.empty?
          raise ArgumentError, "Empty values object"
        end
      end

      def verify_attributes(conditions, assigns)
        if read_keys != conditions.keys.to_set
          raise ArgumentError, "All objects being updated must have the same condition keys"
        end
        if write_keys != assigns.keys.to_set
          raise ArgumentError, "All objects being updated must have the same assignment keys"
        end
      end

      def normalize_updates(updates)
        if updates.is_a?(Hash)
          if model.composite_primary_key?
            updates.map { |id, assigns| [model.primary_key.zip(id).to_h, assigns] }
          elsif updates.keys.first.is_a?(Array)
            updates.map { |id, assigns| [{ model.primary_key => id.fetch(0) }, assigns] }
          else
            updates.map { |id, assigns| [{ model.primary_key => id }, assigns] }
          end
        else
          updates
        end.map do |conditions, assigns|
          [conditions.stringify_keys, assigns.stringify_keys]
        end
      end

      def map_key_with_value
        updates.map do |conditions, assigns|
          verify_attributes(conditions, assigns)

          condition_values = read_keys.map { |key| yield key, conditions[key] }
          write_values = write_keys.map { |key| yield key, assigns[key] }
          condition_values.concat(write_values)
        end
      end

      def record_timestamps?
        @record_timestamps
      end

      def timestamp_keys
        @timestamp_keys ||= record_timestamps? ? model.timestamp_attributes_for_update_in_model.to_set - write_keys : []
      end

      def resolve_attribute_aliases
        return unless has_attribute_aliases?(@updates.first.first) || has_attribute_aliases?(@updates.first.last)

        @updates.map! do |conditions, assigns|
          [conditions.transform_keys { |attribute| resolve_attribute_alias(attribute) },
           assigns.transform_keys { |attribute| resolve_attribute_alias(attribute) }]
        end
      end

      def resolve_attribute_alias(attribute)
        model.attribute_alias(attribute) || attribute
      end

      def has_attribute_aliases?(attributes)
        attributes.keys.any? { |attribute| model.attribute_alias?(attribute) }
      end

      def extract_types_from_columns_on(table_name, keys:)
        columns = @model.schema_cache.columns_hash(table_name)

        unknown_column = (keys - columns.keys).first
        raise UnknownAttributeError.new(model.new, unknown_column) if unknown_column

        keys.index_with { |key| model.type_for_attribute(key) }
      end
  end
end
