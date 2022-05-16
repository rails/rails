# frozen_string_literal: true

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
            ::Range.new(*sanitize_bounds(from, to), extracted[:exclude_end])
          end

          def serialize(value)
            if value.is_a?(::Range)
              from = type_cast_single_for_database(value.begin)
              to = type_cast_single_for_database(value.end)
              ::Range.new(from, to, value.exclude_end?)
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

          def force_equality?(value)
            value.is_a?(::Range)
          end

          private
            def type_cast_single(value)
              infinity?(value) ? value : @subtype.deserialize(value)
            end

            def type_cast_single_for_database(value)
              infinity?(value) ? value : @subtype.serialize(@subtype.cast(value))
            end

            def extract_bounds(value)
              from, to = value[1..-2].split(",", 2)
              {
                from:          (from == "" || from == "-infinity") ? infinity(negative: true) : unquote(from),
                to:            (to == "" || to == "infinity") ? infinity : unquote(to),
                exclude_start: value.start_with?("("),
                exclude_end:   value.end_with?(")")
              }
            end

            INFINITE_FLOAT_RANGE = (-::Float::INFINITY)..(::Float::INFINITY) # :nodoc:

            def sanitize_bounds(from, to)
              [
                (from == -::Float::INFINITY && !INFINITE_FLOAT_RANGE.cover?(to)) ? nil : from,
                (to == ::Float::INFINITY && !INFINITE_FLOAT_RANGE.cover?(from)) ? nil : to
              ]
            end

            # When formatting the bound values of range types, PostgreSQL quotes
            # the bound value using double-quotes in certain conditions. Within
            # a double-quoted string, literal " and \ characters are themselves
            # escaped. In input, PostgreSQL accepts multiple escape styles for "
            # (either \" or "") but in output always uses "".
            # See:
            # * https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-IO
            # * https://www.postgresql.org/docs/current/rowtypes.html#ROWTYPES-IO-SYNTAX
            def unquote(value)
              if value.start_with?('"') && value.end_with?('"')
                unquoted_value = value[1..-2]
                unquoted_value.gsub!('""', '"')
                unquoted_value.gsub!("\\\\", "\\")
                unquoted_value
              else
                value
              end
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
