# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Timestamp < DateTime # :nodoc:
        end
      end
    end
  end
end
