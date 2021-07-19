# frozen_string_literal: true

module ActiveRecord
  module Type
    class Json < ActiveModel::Type::Value
      include ActiveModel::Type::Helpers::Mutable

      def type
        :json
      end

      def deserialize(value)
        return value unless value.is_a?(::String)
        ActiveSupport::JSON.decode(value) rescue nil
      end

      def serialize(value)
        ActiveSupport::JSON.encode(value) unless value.nil?
      end

      def accessor
        ActiveRecord::Store::StringKeyedHashAccessor
      end
    end
  end
end
