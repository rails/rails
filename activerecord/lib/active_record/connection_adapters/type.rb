require 'active_record/connection_adapters/type/value'
require 'active_record/connection_adapters/type/binary'
require 'active_record/connection_adapters/type/boolean'
require 'active_record/connection_adapters/type/date'
require 'active_record/connection_adapters/type/date_time'
require 'active_record/connection_adapters/type/decimal'
require 'active_record/connection_adapters/type/float'
require 'active_record/connection_adapters/type/integer'
require 'active_record/connection_adapters/type/string'
require 'active_record/connection_adapters/type/text'
require 'active_record/connection_adapters/type/time'
require 'active_record/connection_adapters/type/type_map'

module ActiveRecord
  module ConnectionAdapters
    module Type # :nodoc:
      class << self
        def extract_scale(sql_type)
          case sql_type
            when /^(numeric|decimal|number)\((\d+)\)/i then 0
            when /^(numeric|decimal|number)\((\d+)(,(\d+))\)/i then $4.to_i
          end
        end
      end
    end
  end
end
