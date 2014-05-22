module ActiveRecord
  module ConnectionAdapters
    module Type
      module Numeric # :nodoc:
        def number?
          true
        end

        def type_cast_for_write(value)
          case value
          when true then 1
          when false then 0
          when ::String then value.presence
          else super
          end
        end

        def extract_precision(sql_type)
          $1.to_i if sql_type =~ /\((\d+)(,\d+)?\)/
        end
      end
    end
  end
end
