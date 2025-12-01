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
        begin
          ActiveSupport::JSON.decode(value)
        rescue JSON::ParserError => e
          # NOTE: This may hide json with duplicate keys. We don't really want to just ignore it
          # but it's the best we can do in order to still allow updating columns that somehow already
          # contain invalid json from some other source.
          # See https://github.com/rails/rails/pull/55536
          ActiveSupport.error_reporter.report(e, source: "application.active_record")
          nil
        end
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
