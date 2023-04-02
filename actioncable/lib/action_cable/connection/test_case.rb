# frozen_string_literal: true

require "active_support"
require "active_support/test_case"
require "active_support/core_ext/hash/indifferent_access"
require "action_dispatch"
require "action_dispatch/http/headers"
require "action_dispatch/testing/test_request"

module ActionCable
  module Connection
    class NonInferrableConnectionError < ::StandardError
      def initialize(name)
        super "Unable to determine the connection to test from #{name}. " +
          "You'll need to specify it using `tests YourConnection` in your " +
          "test case definition."
      end
    end

    module Assertions
      # Asserts that the connection is rejected (via +reject_unauthorized_connection+).
      #
      #   # Asserts that connection without user_id fails
      #   assert_reject_connection { connect params: { user_id: '' } }
      def assert_reject_connection(&block)
        assert_raises(Authorization::UnauthorizedError, "Expected to reject connection but no rejection was made", &block)
      end
    end

    # We don't want to use the whole "encryption stack" for connection
    # unit-tests, but we want to make sure that users test against the correct types
    # of cookies (i.e. signed or encrypted or plain)
    class TestCookieJar < ActiveSupport::HashWithIndifferentAccess
      def signed
        self[:signed] ||= {}.with_indifferent_access
      end

      def encrypted
        self[:encrypted] ||= {}.with_indifferent_access
      end
    end

    class TestRequest < ActionDispatch::TestRequest
      attr_accessor :session, :cookie_jar
    end

    module TestConnection
      attr_reader :logger, :request

      def initialize(request)
        inner_logger = ActiveSupport::Logger.new(StringIO.new)
        tagged_logging = ActiveSupport::TaggedLogging.new(inner_logger)
        @logger = ActionCable::Connection::TaggedLoggerProxy.new(tagged_logging, tags: [])
        @request = request
        @env = request.env
      end
    end

    # = Action Cable \Connection \TestCase
    #
    # Unit test Action Cable connections.
    #
    # Useful to check whether a connection's +identified_by+ gets assigned properly
    # and that any improper connection requests are rejected.
    #
    # == Basic example
    #
    # Unit tests are written as follows:
    #
    # 1. Simulate a connection attempt by calling +connect+.
    # 2. Assert state, e.g. identifiers, has been assigned.
    #
    #
    #   class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
    #     def test_connects_with_proper_cookie
    #       # Simulate the connection request with a cookie.
    #       cookies["user_id"] = users(:john).id
    #
    #       connect
    #
    #       # Assert the connection identifier matches the fixture.
    #       assert_equal users(:john).id, connection.user.id
    #     end
    #
    #     def test_rejects_connection_without_proper_cookie
    #       assert_reject_connection { connect }
    #     end
    #   end
    #
    # +connect+ accepts additional information about the HTTP request with the
    # +params+, +headers+, +session+, and Rack +env+ options.
    #
    #   def test_connect_with_headers_and_query_string
    #     connect params: { user_id: 1 }, headers: { "X-API-TOKEN" => "secret-my" }
    #
    #     assert_equal "1", connection.user.id
    #     assert_equal "secret-my", connection.token
    #   end
    #
    #   def test_connect_with_params
    #     connect params: { user_id: 1 }
    #
    #     assert_equal "1", connection.user.id
    #   end
    #
    # You can also set up the correct cookies before the connection request:
    #
    #   def test_connect_with_cookies
    #     # Plain cookies:
    #     cookies["user_id"] = 1
    #
    #     # Or signed/encrypted:
    #     # cookies.signed["user_id"] = 1
    #     # cookies.encrypted["user_id"] = 1
    #
    #     connect
    #
    #     assert_equal "1", connection.user_id
    #   end
    #
    # == \Connection is automatically inferred
    #
    # ActionCable::Connection::TestCase will automatically infer the connection under test
    # from the test class name. If the channel cannot be inferred from the test
    # class name, you can explicitly set it with +tests+.
    #
    #   class ConnectionTest < ActionCable::Connection::TestCase
    #     tests ApplicationCable::Connection
    #   end
    #
    class TestCase < ActiveSupport::TestCase
      module Behavior
        extend ActiveSupport::Concern

        DEFAULT_PATH = "/cable"

        include ActiveSupport::Testing::ConstantLookup
        include Assertions

        included do
          class_attribute :_connection_class

          attr_reader :connection

          ActiveSupport.run_load_hooks(:action_cable_connection_test_case, self)
        end

        module ClassMethods
          def tests(connection)
            case connection
            when String, Symbol
              self._connection_class = connection.to_s.camelize.constantize
            when Module
              self._connection_class = connection
            else
              raise NonInferrableConnectionError.new(connection)
            end
          end

          def connection_class
            if connection = self._connection_class
              connection
            else
              tests determine_default_connection(name)
            end
          end

          def determine_default_connection(name)
            connection = determine_constant_from_test_name(name) do |constant|
              Class === constant && constant < ActionCable::Connection::Base
            end
            raise NonInferrableConnectionError.new(name) if connection.nil?
            connection
          end
        end

        # Performs connection attempt to exert #connect on the connection under test.
        #
        # Accepts request path as the first argument and the following request options:
        #
        # - params – URL parameters (Hash)
        # - headers – request headers (Hash)
        # - session – session data (Hash)
        # - env – additional Rack env configuration (Hash)
        def connect(path = ActionCable.server.config.mount_path, **request_params)
          path ||= DEFAULT_PATH

          connection = self.class.connection_class.allocate
          connection.singleton_class.include(TestConnection)
          connection.send(:initialize, build_test_request(path, **request_params))
          connection.connect if connection.respond_to?(:connect)

          # Only set instance variable if connected successfully
          @connection = connection
        end

        # Exert #disconnect on the connection under test.
        def disconnect
          raise "Must be connected!" if connection.nil?

          connection.disconnect if connection.respond_to?(:disconnect)
          @connection = nil
        end

        def cookies
          @cookie_jar ||= TestCookieJar.new
        end

        private
          def build_test_request(path, params: nil, headers: {}, session: {}, env: {})
            wrapped_headers = ActionDispatch::Http::Headers.from_hash(headers)

            uri = URI.parse(path)

            query_string = params.nil? ? uri.query : params.to_query

            request_env = {
              "QUERY_STRING" => query_string,
              "PATH_INFO" => uri.path
            }.merge(env)

            if wrapped_headers.present?
              ActionDispatch::Http::Headers.from_hash(request_env).merge!(wrapped_headers)
            end

            TestRequest.create(request_env).tap do |request|
              request.session = session.with_indifferent_access
              request.cookie_jar = cookies
            end
          end
      end

      include Behavior
    end
  end
end
