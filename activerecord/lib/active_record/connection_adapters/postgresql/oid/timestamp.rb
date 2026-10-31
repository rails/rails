# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Timestamp < DateTime # :nodoc:
          def type
            real_type_unless_aliased(:timestamp)
          end
        end
      end
    end
  end
end
