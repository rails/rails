# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class ModelMetadata # :nodoc:
      def initialize(model_class)
        @model_class = model_class
      end

      def primary_key_name
        @primary_key_name ||= @model_class && @model_class.primary_key
      end

      def primary_key_type
        @primary_key_type ||= @model_class && @model_class.type_for_attribute(@model_class.primary_key).type
      end

      def has_primary_key_column?
        @has_primary_key_column ||= primary_key_name &&
          @model_class.columns.any? { |col| col.name == primary_key_name }
      end

      def timestamp_column_names
        @model_class.all_timestamp_attributes_in_model
      end

      def inheritance_column_name
        @inheritance_column_name ||= @model_class && @model_class.inheritance_column
      end
    end
  end
end
