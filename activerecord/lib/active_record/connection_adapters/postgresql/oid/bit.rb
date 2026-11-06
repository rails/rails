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
                value[2..-1].hex.to_s(2) # Hexadecimal notation
              else
                value                    # Bit-string notation
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

            # Lets ActiveSupport::MessagePack::CacheSerializer dump records with
            # attributes of this type. They load as the String the database returns.
            def self.from_msgpack_ext(value)
              value
            end

            def to_msgpack_ext
              to_s
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
