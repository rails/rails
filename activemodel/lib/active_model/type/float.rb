# frozen_string_literal: true

# :markup: markdown
require "active_support/core_ext/object/try"

module ActiveModel
  module Type
    # Active Model \Float \Type
    # =========================
    #
    # Attribute type for floating point numeric values. It is registered under
    # the `:float` key.
    #
    # ```
    # class BagOfCoffee
    #   include ActiveModel::Attributes
    #
    #   attribute :weight, :float
    # end
    #
    # bag = BagOfCoffee.new
    #
    # bag.weight = "0.25"
    # bag.weight # => 0.25
    #
    # bag.weight = ""
    # bag.weight # => nil
    #
    # bag.weight = "NaN"
    # bag.weight # => Float::NAN
    # ```
    #
    # Values are cast using their `to_f` method, except for the following
    # strings:
    #
    # - Blank strings are cast to `nil`.
    # - `"Infinity"` is cast to `Float::INFINITY`.
    # - `"-Infinity"` is cast to `-Float::INFINITY`.
    # - `"NaN"` is cast to `Float::NAN`.
    class Float < Value
      include Helpers::Immutable
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
          else
            Float(value) rescue nil
          end
        end
    end
  end
end
