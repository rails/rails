# frozen_string_literal: true

# :markup: markdown

require "rack/version"

module ActionDispatch
  module Constants
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
