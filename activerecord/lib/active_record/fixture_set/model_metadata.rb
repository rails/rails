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
        @primary_key_type ||= @model_class && column_type(@model_class.primary_key)
      end

      def column_type(column_name)
        @column_type ||= {}
        return @column_type[column_name] if @column_type.key?(column_name)

        @column_type[column_name] = @model_class && @model_class.type_for_attribute(column_name).type
      end

      def has_column?(column_name)
        column_names.include?(column_name)
      end

      def column_names
        @column_names ||= @model_class ? @model_class.columns.map(&:name).to_set : Set.new
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
