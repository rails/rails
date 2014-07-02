require 'active_record/connection_adapters/postgresql/oid/integer'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class BigInteger < Integer # :nodoc:
          def type
            :big_integer
          end

          def limit
            8
          end
        end
      end
    end
  end
end
