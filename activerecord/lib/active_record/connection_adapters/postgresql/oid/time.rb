module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Time < Type::Time
          include Infinity
        end
      end
    end
  end
end
