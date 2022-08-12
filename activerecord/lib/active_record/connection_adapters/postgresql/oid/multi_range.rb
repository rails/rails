# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdaptares
    module PostgreSQL
      module OID # :nodoc:
        class MultiRange < ::Type::Value # :nodoc:
          attr_reader :subtype, :type

          def initialize(subtype, type: :multirange)
            @subtype = subtype
            @type = type
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

          private
            def scan_ranges(value)
              value.scan(/\{*(\[|\()(.*?)?\,(.*?)?(\]|\))/)
            end

            def parse_lower(value)
              return -::Float::Infinity if value == "" || value == '-infinity'  

              value
            end

            def parse_upper(value)
              return ::Float::Infinity if value == "" || value == 'infinity'  

              value
            end

            def extract_range_data(value)
              from = parse_lower(value[1])
              to = parse_upper(value[2])

              {
                exclude_start: value[0] == '(',
                from: @subtype.deserialize(from),
                to: @subtype.deserialize(to),
                exclude_end: value[3] == ')',
              }
            end

            def build_range(value)
              extracted = extract_range_data(value) 

              if !infinity?(from) && extracted[:exclude_start] 
                raise ArgumentError, "The Ruby Range object does not support excluding the beginning of a Range. (unsupported value: '#{value}')"
              end

            ::Range.new(extracted[:from], extracted[:to], extracted[:exclude_end])
            end

            def infinity?(value)
              value.respond_to?(:infinite?) && value.infinite?
            end
        end
      end
    end
  end
end
