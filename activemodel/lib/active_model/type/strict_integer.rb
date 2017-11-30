# frozen_string_literal: true

module ActiveModel
  module Type
    class StrictInteger < Integer  # :nodoc:
      private

        def cast_value(value)
          case value
          when true then 1
          when false then 0
          when /\A[\d\.]+\Z/ then value.to_i
          else
            Integer(value) rescue nil
          end
        end
    end
  end
end
