# frozen_string_literal: true

require "active_support/json"

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

      JSON_ENCODER = ActiveSupport::JSON::Encoding.json_encoder.new(escape: false)

      def serialize(value)
        JSON_ENCODER.encode(value) unless value.nil?
      end

      def changed_in_place?(raw_old_value, new_value)
        deserialize(raw_old_value) != new_value
      end

      def accessor
        ActiveRecord::Store::StringKeyedHashAccessor
      end
    end
  end
end
