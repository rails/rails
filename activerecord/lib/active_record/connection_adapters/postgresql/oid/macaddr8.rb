# frozen_string_literal: true

require "active_record/connection_adapters/postgresql/oid/macaddr"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Macaddr8 < Macaddr # :nodoc:
          def type
            :macaddr8
          end
        end
      end
    end
  end
end
