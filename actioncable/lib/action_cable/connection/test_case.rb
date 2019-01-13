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
        res =
          begin
            block.call
            false
          rescue ActionCable::Connection::Authorization::UnauthorizedError
            true
          end

        assert res, "Expected to reject connection but no rejection were made"
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

      attr_writer :cookie_jar
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

    # Superclass for Action Cable connection unit tests.
    #
    # == Basic example
    #
    # Unit tests are written as follows:
    # 1. First, one uses the +connect+ method to simulate connection.
    # 2. Then, one asserts whether the current state is as expected (e.g. identifiers).
    #
    # For example:
    #
    #   module ApplicationCable
    #     class ConnectionTest < ActionCable::Connection::TestCase
    #       def test_connects_with_cookies
    #         cookies["user_id"] = users[:john].id
    #         # Simulate a connection
    #         connect
    #
    #         # Asserts that the connection identifier is correct
    #         assert_equal "John", connection.user.name
    #       end
    #
    #       def test_does_not_connect_without_user
    #         assert_reject_connection do
    #           connect
    #         end
    #       end
    #     end
    #   end
    #
    # You can also provide additional information about underlying HTTP request
    # (params, headers, session and Rack env):
    #
    #   def test_connect_with_headers_and_query_string
    #     connect "/cable?user_id=1", headers: { "X-API-TOKEN" => 'secret-my' }
    #
    #     assert_equal connection.user_id, "1"
    #   end
    #
    #   def test_connect_with_params
    #     connect params: { user_id: 1 }
    #
    #     assert_equal connection.user_id, "1"
    #   end
    #
    # You can also manage request cookies:
    #
    #   def test_connect_with_cookies
    #     # plain cookies
    #     cookies["user_id"] = 1
    #     # or signed/encrypted
    #     # cookies.signed["user_id"] = 1
    #
    #     connect
    #
    #     assert_equal connection.user_id, "1"
    #   end
    #
    # == Connection is automatically inferred
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

        # Performs connection attempt (i.e. calls #connect method).
        #
        # Accepts request path as the first argument and the following request options:
        # - params – url parameters (Hash)
        # - headers – request headers (Hash)
        # - session – session data (Hash)
        # - env – addittional Rack env configuration (Hash)
        def connect(path = ActionCable.server.config.mount_path, **request_params)
          path ||= DEFAULT_PATH

          connection = self.class.connection_class.allocate
          connection.singleton_class.include(TestConnection)
          connection.send(:initialize, build_test_request(path, request_params))
          connection.connect if connection.respond_to?(:connect)

          # Only set instance variable if connected successfully
          @connection = connection
        end

        # Disconnect the connection under test (i.e. calls #disconnect)
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
