module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Date < Type::Date # :nodoc:
          include Infinity
        end
      end
    end
  end
end
