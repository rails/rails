# frozen_string_literal: true

module ActiveRecord
  module Coders # :nodoc:
    class JSON # :nodoc:
      def initialize(options = {})
        @options = options
      end

      def dump(obj)
        ActiveSupport::JSON.encode(obj)
      end

      def load(json)
        ActiveSupport::JSON.decode(json, @options) unless json.blank?
      end
    end
  end
end
