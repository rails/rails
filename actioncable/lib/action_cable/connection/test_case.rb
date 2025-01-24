# frozen_string_literal: true

# :markup: markdown

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
      # Asserts that the connection is rejected (via
      # `reject_unauthorized_connection`).
      #
      #     # Asserts that connection without user_id fails
      #     assert_reject_connection { connect params: { user_id: '' } }
      def assert_reject_connection(&block)
        assert_raises(Authorization::UnauthorizedError, "Expected to reject connection but no rejection was made", &block)
      end
    end

    class TestCookies < ActiveSupport::HashWithIndifferentAccess # :nodoc:
      def []=(name, options)
        value = options.is_a?(Hash) ? options.symbolize_keys[:value] : options
        super(name, value)
      end
    end

    # We don't want to use the whole "encryption stack" for connection unit-tests,
    # but we want to make sure that users test against the correct types of cookies
    # (i.e. signed or encrypted or plain)
    class TestCookieJar < TestCookies
      def signed
        @signed ||= TestCookies.new
      end

      def encrypted
        @encrypted ||= TestCookies.new
      end
    end

    class TestSocket
      # Make session and cookies available to the connection
      class Request < ActionDispatch::TestRequest
        attr_accessor :session, :cookie_jar
      end

      attr_reader :logger, :request, :transmissions, :closed, :env

      class << self
        def build_request(path, params: nil, headers: {}, session: {}, env: {}, cookies: nil)
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

          Request.create(request_env).tap do |request|
            request.session = session.with_indifferent_access
            request.cookie_jar = cookies
          end
        end
      end

      def initialize(request)
        inner_logger = ActiveSupport::Logger.new(StringIO.new)
        tagged_logging = ActiveSupport::TaggedLogging.new(inner_logger)
        @logger = ActionCable::Server::TaggedLoggerProxy.new(tagged_logging, tags: [])
        @request = request
        @env = request.env
        @connection = nil
        @closed = false
        @transmissions = []
      end

      def transmit(data)
        @transmissions << data.with_indifferent_access
      end

      def close
        @closed = true
      end
    end

    # TestServer provides test pub/sub and executor implementations
    class TestServer
      attr_reader :streams, :config

      def initialize(server)
        @streams = Hash.new { |h, k| h[k] = [] }
        @config = server.config
      end

      alias_method :pubsub, :itself
      alias_method :executor, :itself

      #== Executor interface ==

      # Inline async calls
      def post(&work) = work.call
      # We don't support timers in unit tests yet
      def timer(_every) = nil

      #== Pub/sub interface ==
      def subscribe(stream, callback, success_callback = nil)
        @streams[stream] << callback
        success_callback&.call
      end

      def unsubscribe(stream, callback)
        @streams[stream].delete(callback)
        @streams.delete(stream) if @streams[stream].empty?
      end
    end

    # # Action Cable Connection TestCase
    #
    # Unit test Action Cable connections.
    #
    # Useful to check whether a connection's `identified_by` gets assigned properly
    # and that any improper connection requests are rejected.
    #
    # ## Basic example
    #
    # Unit tests are written by first simulating a connection attempt by calling
    # `connect` and then asserting state, e.g. identifiers, have been assigned.
    #
    #     class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
    #       def test_connects_with_proper_cookie
    #         # Simulate the connection request with a cookie.
    #         cookies["user_id"] = users(:john).id
    #
    #         connect
    #
    #         # Assert the connection identifier matches the fixture.
    #         assert_equal users(:john).id, connection.user.id
    #       end
    #
    #       def test_rejects_connection_without_proper_cookie
    #         assert_reject_connection { connect }
    #       end
    #     end
    #
    # `connect` accepts additional information about the HTTP request with the
    # `params`, `headers`, `session`, and Rack `env` options.
    #
    #     def test_connect_with_headers_and_query_string
    #       connect params: { user_id: 1 }, headers: { "X-API-TOKEN" => "secret-my" }
    #
    #       assert_equal "1", connection.user.id
    #       assert_equal "secret-my", connection.token
    #     end
    #
    #     def test_connect_with_params
    #       connect params: { user_id: 1 }
    #
    #       assert_equal "1", connection.user.id
    #     end
    #
    # You can also set up the correct cookies before the connection request:
    #
    #     def test_connect_with_cookies
    #       # Plain cookies:
    #       cookies["user_id"] = 1
    #
    #       # Or signed/encrypted:
    #       # cookies.signed["user_id"] = 1
    #       # cookies.encrypted["user_id"] = 1
    #
    #       connect
    #
    #       assert_equal "1", connection.user_id
    #     end
    #
    # ## Connection is automatically inferred
    #
    # ActionCable::Connection::TestCase will automatically infer the connection
    # under test from the test class name. If the channel cannot be inferred from
    # the test class name, you can explicitly set it with `tests`.
    #
    #     class ConnectionTest < ActionCable::Connection::TestCase
    #       tests ApplicationCable::Connection
    #     end
    #
    class TestCase < ActiveSupport::TestCase
      module Behavior
        extend ActiveSupport::Concern

        DEFAULT_PATH = "/cable"

        include ActiveSupport::Testing::ConstantLookup
        include Assertions

        included do
          class_attribute :_connection_class

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

        attr_reader :connection, :socket, :testserver

        # Performs connection attempt to exert #connect on the connection under test.
        #
        # Accepts request path as the first argument and the following request options:
        #
        # *   params – URL parameters (Hash)
        # *   headers – request headers (Hash)
        # *   session – session data (Hash)
        # *   env – additional Rack env configuration (Hash)
        def connect(path = ActionCable.server.config.mount_path, server: ActionCable.server, **request_params)
          path ||= DEFAULT_PATH

          @socket = TestSocket.new(TestSocket.build_request(path, **request_params, cookies: cookies))
          @testserver = Connection::TestServer.new(server)
          connection = self.class.connection_class.new(@testserver, socket)
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

        def transmissions
          socket&.transmissions || []
        end
      end

      include Behavior
    end
  end
end
