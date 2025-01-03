# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActiveModel
  module Type
    # = Active Model \Float \Type
    #
    # Attribute type for floating point numeric values. It is registered under
    # the +:float+ key.
    #
    #   class BagOfCoffee
    #     include ActiveModel::Attributes
    #
    #     attribute :weight, :float
    #   end
    #
    #   bag = BagOfCoffee.new
    #
    #   bag.weight = "0.25"
    #   bag.weight # => 0.25
    #
    #   bag.weight = ""
    #   bag.weight # => nil
    #
    #   bag.weight = "NaN"
    #   bag.weight # => Float::NAN
    #
    # Values are cast using their +to_f+ method, except for the following
    # strings:
    #
    # - Blank strings are cast to +nil+.
    # - <tt>"Infinity"</tt> is cast to +Float::INFINITY+.
    # - <tt>"-Infinity"</tt> is cast to <tt>-Float::INFINITY</tt>.
    # - <tt>"NaN"</tt> is cast to +Float::NAN+.
    class Float < Value
      include Helpers::Numeric

      def type
        :float
      end

      def type_cast_for_schema(value)
        return "::Float::NAN" if value.try(:nan?)
        case value
        when ::Float::INFINITY then "::Float::INFINITY"
        when -::Float::INFINITY then "-::Float::INFINITY"
        else super
        end
      end

      private
        def cast_value(value)
          case value
          when ::Float then value
          when "Infinity" then ::Float::INFINITY
          when "-Infinity" then -::Float::INFINITY
          when "NaN" then ::Float::NAN
          else value.to_f
          end
        end
    end
  end
end
