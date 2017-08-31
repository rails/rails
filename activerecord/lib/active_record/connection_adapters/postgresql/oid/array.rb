# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Array < Type::Value # :nodoc:
          include Type::Helpers::Mutable

          Data = Struct.new(:encoder, :values) # :nodoc:

          attr_reader :subtype, :delimiter
          delegate :type, :user_input_in_time_zone, :limit, :precision, :scale, to: :subtype

          def initialize(subtype, delimiter = ",")
            @subtype = subtype
            @delimiter = delimiter

            @pg_encoder = PG::TextEncoder::Array.new name: "#{type}[]", delimiter: delimiter
            @pg_decoder = PG::TextDecoder::Array.new name: "#{type}[]", delimiter: delimiter
          end

          def deserialize(value)
            case value
            when ::String
              type_cast_array(@pg_decoder.decode(value), :deserialize)
            when Data
              type_cast_array(value.values, :deserialize)
            else
              super
            end
          end

          def cast(value)
            if value.is_a?(::String)
              value = @pg_decoder.decode(value)
            end
            type_cast_array(value, :cast)
          end

          def serialize(value)
            if value.is_a?(::Array)
              casted_values = type_cast_array(value, :serialize)
              Data.new(@pg_encoder, casted_values)
            else
              super
            end
          end

          def ==(other)
            other.is_a?(Array) &&
              subtype == other.subtype &&
              delimiter == other.delimiter
          end

          def type_cast_for_schema(value)
            return super unless value.is_a?(::Array)
            "[" + value.map { |v| subtype.type_cast_for_schema(v) }.join(", ") + "]"
          end

          def map(value, &block)
            value.map(&block)
          end

          def changed_in_place?(raw_old_value, new_value)
            deserialize(raw_old_value) != new_value
          end

          private

            def type_cast_array(value, method)
              if value.is_a?(::Array)
                value.map { |item| type_cast_array(item, method) }
              else
                @subtype.public_send(method, value)
              end
            end
        end
      end
    end
  end
end
