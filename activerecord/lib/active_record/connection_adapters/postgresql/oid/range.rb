require "active_support/core_ext/string/filters"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Range < Type::Value # :nodoc:
          attr_reader :subtype, :type
          delegate :user_input_in_time_zone, to: :subtype

          def initialize(subtype, type = :range)
            @subtype = subtype
            @type = type
          end

          def type_cast_for_schema(value)
            value.inspect.gsub("Infinity", "::Float::INFINITY")
          end

          def cast_value(value)
            return if value == "empty"
            return value unless value.is_a?(::String)

            extracted = extract_bounds(value)
            from = type_cast_single extracted[:from]
            to = type_cast_single extracted[:to]

            if !infinity?(from) && extracted[:exclude_start]
              raise ArgumentError, "The Ruby Range object does not support excluding the beginning of a Range. (unsupported value: '#{value}')"
            end
            ::Range.new(from, to, extracted[:exclude_end])
          end

          def serialize(value)
            if value.is_a?(::Range)
              from = type_cast_single_for_database(value.begin)
              to = type_cast_single_for_database(value.end)
              "[#{from},#{to}#{value.exclude_end? ? ')' : ']'}"
            else
              super
            end
          end

          def ==(other)
            other.is_a?(Range) &&
              other.subtype == subtype &&
              other.type == type
          end

          def map(value) # :nodoc:
            new_begin = yield(value.begin)
            new_end = yield(value.end)
            ::Range.new(new_begin, new_end, value.exclude_end?)
          end

          private

            def type_cast_single(value)
              infinity?(value) ? value : @subtype.deserialize(value)
            end

            def type_cast_single_for_database(value)
              infinity?(value) ? "" : @subtype.serialize(value)
            end

            def extract_bounds(value)
              from, to = value[1..-2].split(",")
              {
                from:          (value[1] == "," || from == "-infinity") ? infinity(negative: true) : from,
                to:            (value[-2] == "," || to == "infinity") ? infinity : to,
                exclude_start: (value[0] == "("),
                exclude_end:   (value[-1] == ")")
              }
            end

            def infinity(negative: false)
              if subtype.respond_to?(:infinity)
                subtype.infinity(negative: negative)
              elsif negative
                -::Float::INFINITY
              else
                ::Float::INFINITY
              end
            end

            def infinity?(value)
              value.respond_to?(:infinite?) && value.infinite?
            end
        end
      end
    end
  end
end
