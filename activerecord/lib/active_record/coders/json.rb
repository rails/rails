# frozen_string_literal: true

require "active_support/json"

module ActiveRecord
  module Coders
    class JSON # :nodoc:
      DEFAULT_ENCODE_OPTIONS = { escape: false }.freeze

      def initialize(encode_options: nil, decode_options: nil)
        encode_options = encode_options ? DEFAULT_ENCODE_OPTIONS.merge(encode_options) : DEFAULT_ENCODE_OPTIONS
        @decode_options = decode_options
        @encoder = ActiveSupport::JSON::Encoding.json_encoder.new(encode_options)
      end

      def dump(obj)
        @encoder.encode(obj)
      end

      def load(json)
        ActiveSupport::JSON.decode(json, @decode_options) unless json.blank?
      end
    end
  end
end
