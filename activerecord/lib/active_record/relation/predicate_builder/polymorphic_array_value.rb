# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class PolymorphicArrayValue # :nodoc:
      def initialize(associated_table, values)
        @associated_table = associated_table
        @values = values
      end

      def queries
        type_to_ids_mapping.map do |type, ids|
          {
            associated_table.association_foreign_type.to_s => type,
            associated_table.association_foreign_key.to_s => ids
          }
        end
      end

      private
        attr_reader :associated_table, :values

        def type_to_ids_mapping
          default_hash = Hash.new { |hsh, key| hsh[key] = [] }
          values.each_with_object(default_hash) { |value, hash| hash[base_class(value).name] << convert_to_id(value) }
        end

        def primary_key(value)
          associated_table.association_join_primary_key(base_class(value))
        end

        def base_class(value)
          case value
          when Base
            value.class.base_class
          when Relation
            value.klass.base_class
          end
        end

        def convert_to_id(value)
          case value
          when Base
            value._read_attribute(primary_key(value))
          when Relation
            value.select(primary_key(value))
          end
        end
    end
  end
end
