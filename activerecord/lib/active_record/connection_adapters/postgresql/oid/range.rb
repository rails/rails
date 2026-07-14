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
            from = bound_for_schema(value.begin)
            to   = bound_for_schema(value.end)
            op   = value.exclude_end? ? "..." : ".."
            "#{from}#{op}#{to}"
          end

          def cast_value(value)
            return if ["empty", ""].include? value
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
            def bound_for_schema(bound)
              case bound
              when nil
                "nil"
              when ::Float::INFINITY
                "::Float::INFINITY"
              when -::Float::INFINITY
                "-::Float::INFINITY"
              else
                @subtype.type_cast_for_schema(bound)
              end
            end

            def type_cast_single(value)
              infinity?(value) ? value : @subtype.deserialize(value)
            end

            def type_cast_single_for_database(value)
              infinity?(value) ? value : @subtype.serialize(@subtype.cast(value))
            end

            def extract_bounds(value)
              from, to = split_bounds(value[1..-2])
              {
                from:          (from == "" || from == "-infinity") ? infinity(negative: true) : unquote(from),
                to:            (to == "" || to == "infinity") ? infinity : unquote(to),
                exclude_start: value.start_with?("("),
                exclude_end:   value.end_with?(")")
              }
            end

            # Matches the comma-separated lower and upper bounds of a range's
            # textual representation when a bound is double-quoted. A quoted
            # bound can itself contain a comma, so a naive split on the first
            # comma would corrupt such values. Within a double-quoted bound,
            # literal " and \ are escaped (as "" / \" and \\ respectively), so
            # those escapes are skipped while scanning for the separating comma.
            #
            # An unquoted bound never contains a comma or a double-quote
            # (PostgreSQL quotes the whole bound when it would), so the
            # alternation matches an unquoted run with [^,"] rather than [^,].
            # Excluding " keeps the two alternatives mutually exclusive, which
            # removes any ambiguity over how a "-prefixed bound is consumed. The
            # /m flag lets the captured upper bound (and quoted bounds) span
            # newlines.
            BOUNDS = /\A((?:"(?:[^"\\]|""|\\.)*"|[^,"])*),(.*)\z/m # :nodoc:

            def split_bounds(value)
              # Fast path: an unquoted representation (every built-in range
              # type -- int/num/date/timestamp) has no embedded comma, so a
              # plain split is correct and avoids the regexp. Only quoted
              # bounds (custom text/varchar/money/... ranges) need the
              # comma-skipping scan.
              return value.split(",", 2) unless value.include?('"')

              (match = BOUNDS.match(value)) ? [match[1], match[2]] : [value, nil]
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
              if value && value.start_with?('"') && value.end_with?('"')
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
