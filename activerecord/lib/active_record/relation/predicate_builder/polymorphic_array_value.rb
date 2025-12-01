# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class PolymorphicArrayValue # :nodoc:
      def initialize(reflection, values)
        @reflection = reflection
        @values = values
      end

      def queries
        return [ reflection.join_foreign_key => values ] if values.empty?

        type_to_ids_mapping.map do |type, ids|
          query = {}
          query[reflection.join_foreign_type] = type if type
          query[reflection.join_foreign_key] = ids
          query
        end
      end

      private
        attr_reader :reflection, :values

        def type_to_ids_mapping
          default_hash = Hash.new { |hsh, key| hsh[key] = [] }
          values.each_with_object(default_hash) do |value, hash|
            hash[klass(value)&.polymorphic_name] << convert_to_id(value)
          end
        end

        def primary_key(value)
          reflection.join_primary_key(klass(value))
        end

        def klass(value)
          if value.is_a?(Base)
            value.class
          elsif value.is_a?(Relation)
            value.model
          end
        end

        def convert_to_id(value)
          if value.is_a?(Base)
            primary_key = primary_key(value)
            if primary_key.is_a?(Array)
              primary_key.map { |column| value._read_attribute(column) }
            else
              value._read_attribute(primary_key)
            end
          elsif value.is_a?(Relation)
            value.select(primary_key(value))
          else
            value
          end
        end
    end
  end
end
