require 'active_record/connection_adapters/type/value'

module ActiveRecord
  module ConnectionAdapters
    module Type # :nodoc:
      extend ActiveSupport::Autoload

      autoload :Binary
      autoload :Boolean
      autoload :Date
      autoload :DateTime
      autoload :Decimal
      autoload :Float
      autoload :Integer
      autoload :String
      autoload :Text
      autoload :Time
      autoload :Timestamp
      autoload :TypeMap
      autoload :Value

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
