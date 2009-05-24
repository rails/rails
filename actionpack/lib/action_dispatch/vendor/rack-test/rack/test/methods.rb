require "forwardable"

module Rack
  module Test
    module Methods
      extend Forwardable

      def rack_test_session
        @_rack_test_session ||= Rack::Test::Session.new(app)
      end

      def rack_mock_session
        @_rack_mock_session ||= Rack::MockSession.new(app)
      end

      METHODS = [
        :request,

        # HTTP verbs
        :get,
        :post,
        :put,
        :delete,
        :head,

        # Redirects
        :follow_redirect!,

        # Header-related features
        :header,
        :set_cookie,
        :clear_cookies,
        :authorize,
        :basic_authorize,
        :digest_authorize,

        # Expose the last request and response
        :last_response,
        :last_request
      ]

      def_delegators :rack_test_session, *METHODS
    end
  end
end
