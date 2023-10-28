# frozen_string_literal: true

require "active_support/duration"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Interval < ActiveModel::Type::Duration # :nodoc:
          def type
            :interval
          end

          def type_cast_for_schema(value)
            serialize(value).inspect
          end
        end
      end
    end
  end
end
