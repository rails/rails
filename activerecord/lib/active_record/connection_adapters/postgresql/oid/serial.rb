module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Serial < Integer # :nodoc:
        end
      end
    end
  end
end
