# frozen_string_literal: true

module ActiveRecord
  module ModelSchema
    class SchemaContext # :nodoc:
      class Attributes # :nodoc:
        class DatabaseDefaultKeys # :nodoc:
          def initialize(primary_key, columns_hash)
            @primary_key = primary_key
            @columns_hash = columns_hash
          end

          def include?(name)
            @primary_key.include?(name) || !@columns_hash.key?(name)
          end
        end

        attr_reader :defaults, :types, :builder

        def initialize(mapped_table, defaults)
          @defaults = defaults
          @types = defaults.cast_types.tap do |hash|
            hash.default = ActiveModel::Type.default_value
          end
          default_keys = DatabaseDefaultKeys.new(mapped_table.primary_key_definition, mapped_table.columns_hash)
          @builder = ActiveModel::AttributeSet::Builder.new(@types, defaults, default_keys)
          @column_defaults = defaults.to_hash.freeze if defaults.read_only?
        end

        def column_defaults
          @column_defaults ||= defaults.deep_dup.to_hash.freeze
        end
      end
    end
  end
end
