module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bytea < Type::Binary
          def cast_value(value)
            PGconn.unescape_bytea value
          end
        end
      end
    end
  end
end
