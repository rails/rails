module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bit < Type::Value # :nodoc:
          def type
            :bit
          end

          def type_cast(value)
            if ::String === value
              case value
              when /^0x/i
                value[2..-1].hex.to_s(2) # Hexadecimal notation
              else
                value                    # Bit-string notation
              end
            else
              value
            end
          end

          def type_cast_for_database(value)
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
              /\A[01]*\Z/ === value
            end

            def hex?
              /\A[0-9A-F]*\Z/i === value
            end

            protected

            attr_reader :value
          end
        end
      end
    end
  end
end
