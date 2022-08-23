# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class MultiRange < Type::Value # :nodoc:
          Data = Struct.new(:ranges)

          attr_reader :subtype, :type

          def initialize(subtype, type = :multirange)
            @subtype = subtype
            @type = type
          end

          def deserialize(value)
            case value
            when ::String
              cast_value(value)
            when Data
              type_cast_ranges(value.ranges, :deserialize)
            end
          end

          def serialize(value)
            if value.is_a?(::Array)
              Data.new(type_cast_ranges(value, :serialize))
            else
              super
            end
          end

          def cast_value(value)
            return nil if value.blank?
            return value unless value.is_a?(::String)

            ranges = scan_ranges(value)

            ranges.map { |r| build_range(r) }
          end

          def ==(other)
            other.is_a?(MultiRange) &&
              other.subtype == subtype &&
              other.type == type
          end

          def force_equality?(value)
            value.is_a?(::Array)
          end

          private
            def type_cast_ranges(ranges, method)
              ranges.map do |range|
                ::Range.new(
                  @subtype.public_send(method, range.begin),
                  @subtype.public_send(method, range.end),
                  range.exclude_end?
                )
              end
            end

            def scan_ranges(value)
              value.scan(/\{*(\[|\()(.*?)?,(.*?)?(\]|\))/)
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

            def parse_lower(value)
              return infinity_value(value, negative: true) if value == "" || value == "-infinity"

              @subtype.deserialize(unquote(value))
            end

            def parse_upper(value)
              return infinity_value(value) if value == "" || value == "infinity"

              @subtype.deserialize(unquote(value))
            end

            def extract_range_data(value)
              from = parse_lower(value[1])
              to = parse_upper(value[2])

              {
                exclude_start: value[0] == "(",
                from: from,
                to: to,
                exclude_end: value[3] == ")",
              }
            end

            def build_range(value)
              extracted = extract_range_data(value)

              if !infinity?(extracted[:from]) && extracted[:exclude_start]
                raise ArgumentError, "The Ruby Range object does not support excluding the beginning of a Range. (unsupported value: '#{value}')"
              end

              ::Range.new(extracted[:from], extracted[:to], extracted[:exclude_end])
            end

            def infinity_value(value, negative: false)
              if @subtype.respond_to?(:infinity)
                @subtype.infinity(negative: negative)
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
