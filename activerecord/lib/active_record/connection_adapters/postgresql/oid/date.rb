module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Date < Type::Date
          include Infinity
        end
      end
    end
  end
end
