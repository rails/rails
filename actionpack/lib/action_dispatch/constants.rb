# frozen_string_literal: true

require "rack/version"

module ActionDispatch
  module Constants
    # Response Header keys for Rack 2.x and 3.x
    if Gem::Version.new(Rack::RELEASE) < Gem::Version.new("3")
      VARY = "Vary"
      CONTENT_ENCODING = "Content-Encoding"
      LOCATION = "Location"
      FEATURE_POLICY = "Feature-Policy"
      X_REQUEST_ID = "X-Request-Id"
      SERVER_TIMING = "Server-Timing"
    else
      VARY = "vary"
      CONTENT_ENCODING = "content-encoding"
      LOCATION = "location"
      FEATURE_POLICY = "feature-policy"
      X_REQUEST_ID = "x-request-id"
      SERVER_TIMING = "server-timing"
    end
  end
end
