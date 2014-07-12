module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Inet < Cidr # :nodoc:
          def type
            :inet
          end
        end
      end
    end
  end
end
