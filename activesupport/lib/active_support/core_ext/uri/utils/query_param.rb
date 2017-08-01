# frozen_string_literal: true

require "rack/utils"
require_relative "../../hash/keys"

module URI
  module Utils
    module QueryParam
      # Add key/value parameters to a url having (or not) query parameters.
      # Takes a hash and returns a string containing the full and final
      # query parameters.
      #
      #   uri = URI("http://www.test.com?a=b")
      #   uri.add_params({ c: "d" })
      #   uri.to_s
      #   # => "http://www.test.com?a=b&c=d"
      #
      # Keys such as String and/or Symbol are accepted within +params+.
      # If there is a collision with an already existing key, the old value
      # will be replaced by the new one.
      def add_params(params)
        full_params = Rack::Utils.parse_query(query).merge(params.stringify_keys)
        self.query  = Rack::Utils.build_query(full_params)
      end
    end
  end
end
