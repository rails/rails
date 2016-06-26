module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Integer < Type::Integer # :nodoc:
        end
      end
    end
  end
end
