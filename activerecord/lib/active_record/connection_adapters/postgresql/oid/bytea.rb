# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bytea < Type::Binary # :nodoc:
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

                ActiveRecord.deprecator.warn(<<~MSG.squish)
                  bytea column received a binary string for unescaping. In Rails 8.3, binary strings
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
