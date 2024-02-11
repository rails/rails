# frozen_string_literal: true

# :markup: markdown

require "rack/version"

module ActionDispatch
  module Constants
    # Response Header keys for Rack 2.x and 3.x
    if Gem::Version.new(Rack::RELEASE) < Gem::Version.new("3")
      VARY = "Vary"
      CONTENT_ENCODING = "Content-Encoding"
      CONTENT_SECURITY_POLICY = "Content-Security-Policy"
      CONTENT_SECURITY_POLICY_REPORT_ONLY = "Content-Security-Policy-Report-Only"
      LOCATION = "Location"
      FEATURE_POLICY = "Feature-Policy"
      X_REQUEST_ID = "X-Request-Id"
      X_CASCADE = "X-Cascade"
      SERVER_TIMING = "Server-Timing"
      STRICT_TRANSPORT_SECURITY = "Strict-Transport-Security"
    else
      VARY = "vary"
      CONTENT_ENCODING = "content-encoding"
      CONTENT_SECURITY_POLICY = "content-security-policy"
      CONTENT_SECURITY_POLICY_REPORT_ONLY = "content-security-policy-report-only"
      LOCATION = "location"
      FEATURE_POLICY = "feature-policy"
      X_REQUEST_ID = "x-request-id"
      X_CASCADE = "x-cascade"
      SERVER_TIMING = "server-timing"
      STRICT_TRANSPORT_SECURITY = "strict-transport-security"
    end
  end
end
