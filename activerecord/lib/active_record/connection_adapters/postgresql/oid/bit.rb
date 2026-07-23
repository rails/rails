# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bit < Type::Value # :nodoc:
          def type
            :bit
          end

          def cast_value(value)
            if ::String === value
              case value
              when /^0x/i
                # Hexadecimal notation (with possible leading zeroes)
                format("%0*b", (value.rstrip.size - 2) * 4, value[2..].hex)
              else
                # Bit-string notation
                value
              end
            else
              value.to_s
            end
          end

          def serialize(value)
            Data.new(super) if value
          end

          class Data
            def initialize(value)
              @value = value
            end

            def to_s
              value
            end

            def binary?
              /\A[01]*\Z/.match?(value)
            end

            def hex?
              /\A[0-9A-F]*\Z/i.match?(value)
            end

            private
              attr_reader :value
          end
        end
      end
    end
  end
end
