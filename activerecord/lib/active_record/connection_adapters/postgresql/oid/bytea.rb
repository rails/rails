module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bytea < Type::Binary # :nodoc:
          def type_cast_from_database(value)
            return if value.nil?
            PGconn.unescape_bytea(super)
          end
        end
      end
    end
  end
end
