module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Integer < Type::Integer
          include Infinity
        end
      end
    end
  end
end
