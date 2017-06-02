module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Json < Type::Json # :nodoc:
        end
      end
    end
  end
end
