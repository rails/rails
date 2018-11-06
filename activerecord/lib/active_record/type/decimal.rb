# frozen_string_literal: true

module ActiveRecord
  module Type
    class Decimal < ActiveModel::Type::Decimal # :nodoc:
      def serialize(value)
        raise ActiveModel::RangeError, "cannot be infinite" if value&.to_d&.infinite?
        super
      end
    end
  end
end
