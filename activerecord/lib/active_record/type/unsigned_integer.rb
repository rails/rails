# frozen_string_literal: true

module ActiveRecord
  module Type
    class UnsignedInteger < ActiveModel::Type::Integer # :nodoc:
      include ActiveModel::Type::SerializeCastValue

      private
        def max_value
          super * 2
        end

        def min_value
          0
        end
    end
  end
end
