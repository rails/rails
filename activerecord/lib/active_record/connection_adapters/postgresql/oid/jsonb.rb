module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Jsonb < Json # :nodoc:
          def type
            :jsonb
          end
        end
      end
    end
  end
end
