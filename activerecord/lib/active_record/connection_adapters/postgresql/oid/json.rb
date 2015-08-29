module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Json < Type::Internal::AbstractJson
        end
      end
    end
  end
end
