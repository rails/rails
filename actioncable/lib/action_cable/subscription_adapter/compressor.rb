# frozen_string_literal: true

require "active_support/gzip"
require "active_support/core_ext/numeric/bytes"
require "active_support/core_ext/string/access"

module ActionCable
  module SubscriptionAdapter
    class Compressor
      SCHEMA_VERSION = "v1"
      SCHEMA_FORMAT = /#{SCHEMA_VERSION}\/(0|1)\//
      PREFIX_SIZE = "#{SCHEMA_VERSION}/./".size

      def initialize(threshold: 1.kilobyte, compressor: ActiveSupport::Gzip)
        @threshold = threshold
        @compressor = compressor
      end

      def compress(data)
        return "#{SCHEMA_VERSION}/0/#{data}" if data.size < @threshold

        "#{SCHEMA_VERSION}/1/#{@compressor.compress(data)}"
      end

      def decompress(data)
        return data unless valid_schema?(data)

        return data.from(PREFIX_SIZE) unless compressed?(data)

        @compressor.decompress(data.from(PREFIX_SIZE))
      end

      def compressed?(data)
        data.start_with?("#{SCHEMA_VERSION}/1/")
      end

      private
        def valid_schema?(data)
          data.start_with?(SCHEMA_FORMAT)
        end
    end
  end
end
