# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Array < Type::Value # :nodoc:
          include ActiveModel::Type::Helpers::Mutable

          Data = Struct.new(:encoder, :values) # :nodoc:

          # Subtypes whose serialize only returns integers or nil: subclasses may return anything.
          INTEGER_SUBTYPES = [Type::Integer, Type::BigInteger].freeze # :nodoc:

          attr_reader :subtype, :delimiter
          delegate :type, :user_input_in_time_zone, :limit, :precision, :scale, to: :subtype

          def initialize(subtype, delimiter = ",")
            @subtype = subtype
            @delimiter = delimiter
            build_pg_coders
          end

          def deserialize(value)
            case value
            when ::String
              if @pg_integer_decoder
                @pg_integer_decoder.decode(value)
              else
                type_cast_array(@pg_decoder.decode(value), :deserialize)
              end
            when Data
              type_cast_array(value.values, :deserialize)
            else
              super
            end
          end

          def cast(value)
            if value.is_a?(::String)
              value = begin
                @pg_decoder.decode(value)
              rescue TypeError
                # malformed array string is treated as [], will raise in PG 2.0 gem
                # this keeps a consistent implementation
                []
              end
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

          def as_schema_json
            { "subtype" => subtype, "delimiter" => delimiter }
          end

          def init_from_schema_json(coder, references)
            @subtype = references[coder["subtype"]]
            @delimiter = coder["delimiter"]
            build_pg_coders
          end

          def map(value, &block)
            value.is_a?(::Array) ? value.map(&block) : subtype.map(value, &block)
          end

          def changed_in_place?(raw_old_value, new_value)
            deserialize(raw_old_value) != new_value
          end

          def force_equality?(value)
            value.is_a?(::Array)
          end

          private
            def build_pg_coders
              name = "#{type}[]".dedup
              @pg_decoder = PG::TextDecoder::Array.new(name: name, delimiter: @delimiter).freeze

              if INTEGER_SUBTYPES.include?(@subtype.class)
                # pg converts the elements in C, with no String per element. Only deserialize uses
                # the integer decoder: user input given to cast keeps going through the subtype.
                @pg_encoder = PG::TextEncoder::Array.new(name: name, delimiter: @delimiter, elements_type: PG::TextEncoder::Integer.new).freeze
                @pg_integer_decoder = PG::TextDecoder::Array.new(name: name, delimiter: @delimiter, elements_type: PG::TextDecoder::Integer.new).freeze
              else
                @pg_encoder = PG::TextEncoder::Array.new(name: name, delimiter: @delimiter).freeze
                @pg_integer_decoder = nil
              end
            end

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
