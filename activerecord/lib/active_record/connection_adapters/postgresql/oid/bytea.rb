# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bytea < Type::Binary # :nodoc:
          ESCAPED_BYTEA_CHARACTERS = /\A[\x20-\x7e]*\z/n
          private_constant :ESCAPED_BYTEA_CHARACTERS

          def deserialize(value)
            case value
            when nil
              return

            when Type::Binary::Data
              result = value.to_s
              if result.instance_variable_defined?(:@ar_pg_bytea_decoded)
                result = result.dup
                result.remove_instance_variable(:@ar_pg_bytea_decoded)
              end
              return result

            when String
              if value.instance_variable_get(:@ar_pg_bytea_decoded)
                result = value.dup
                result.remove_instance_variable(:@ar_pg_bytea_decoded)
                return result

              elsif value.encoding == Encoding::BINARY &&
                  !value.instance_variable_defined?(:@ar_pg_bytea_decoded)

                # Escaped bytea output is always printable ASCII, so anything
                # else is already decoded data that lost its marker.
                return value unless value.match?(ESCAPED_BYTEA_CHARACTERS)

                ActiveRecord.deprecator.warn(<<~MSG.squish)
                  bytea column received a binary string for unescaping. In Rails 9.0, binary strings
                  will be treated as already unescaped.
                MSG
              end

            else
              value = super
            end

            PG::Connection.unescape_bytea(value)
          end
        end
      end
    end
  end
end
