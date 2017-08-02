# frozen_string_literal: true

module ActiveRecord
  module Type
    class String < ActiveModel::Type::String # :nodoc:
      def serialize(value)
        case value
        when true then "t"
        when false then "f"
        else super
        end
      end

      private
        def cast_value(value)
          case value
          when true then "t"
          when false then "f"
          else super
          end
        end
    end
  end
end
