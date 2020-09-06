# frozen_string_literal: true

require 'abstract_unit'
require 'action_dispatch/testing/assertions/response'

module ActionDispatch
  module Assertions
    class ResponseAssertionsTest < ActiveSupport::TestCase
      include ResponseAssertions

      FakeResponse = Struct.new(:response_code, :location, :body) do
        def initialize(*)
          super
          self.location ||= 'http://test.example.com/posts'
          self.body ||= ''
        end

        [:successful, :not_found, :redirection, :server_error].each do |sym|
          define_method("#{sym}?") do
            sym == response_code
          end
        end
      end

      def setup
        @controller = nil
        @request = nil
      end

      def test_assert_response_predicate_methods
        [:success, :missing, :redirect, :error].each do |sym|
          @response = FakeResponse.new RESPONSE_PREDICATES[sym].to_s.sub(/\?/, '').to_sym
          assert_response sym

          assert_raises(Minitest::Assertion) {
            assert_response :unauthorized
          }
        end
      end

      def test_assert_response_integer
        @response = FakeResponse.new 400
        assert_response 400

        assert_raises(Minitest::Assertion) {
          assert_response :unauthorized
        }

        assert_raises(Minitest::Assertion) {
          assert_response 500
        }
      end

      def test_assert_response_sym_status
        @response = FakeResponse.new 401
        assert_response :unauthorized

        assert_raises(Minitest::Assertion) {
          assert_response :ok
        }

        assert_raises(Minitest::Assertion) {
          assert_response :success
        }
      end

      def test_assert_response_sym_typo
        @response = FakeResponse.new 200

        assert_raises(ArgumentError) {
          assert_response :succezz
        }
      end

      def test_error_message_shows_404_when_404_asserted_for_success
        @response = ActionDispatch::Response.new
        @response.status = 404

        error = assert_raises(Minitest::Assertion) { assert_response :success }
        expected = 'Expected response to be a <2XX: success>,'\
                   ' but was a <404: Not Found>'
        assert_match expected, error.message
      end

      def test_error_message_shows_404_when_asserted_for_200
        @response = ActionDispatch::Response.new
        @response.status = 404

        error = assert_raises(Minitest::Assertion) { assert_response 200 }
        expected = 'Expected response to be a <200: OK>,'\
                   ' but was a <404: Not Found>'
        assert_match expected, error.message
      end

      def test_error_message_shows_302_redirect_when_302_asserted_for_success
        @response = ActionDispatch::Response.new
        @response.status = 302
        @response.location = 'http://test.host/posts/redirect/1'

        error = assert_raises(Minitest::Assertion) { assert_response :success }
        expected = 'Expected response to be a <2XX: success>,'\
                   ' but was a <302: Found>' \
                   ' redirect to <http://test.host/posts/redirect/1>'
        assert_match expected, error.message
      end

      def test_error_message_shows_302_redirect_when_302_asserted_for_301
        @response = ActionDispatch::Response.new
        @response.status = 302
        @response.location = 'http://test.host/posts/redirect/2'

        error = assert_raises(Minitest::Assertion) { assert_response 301 }
        expected = 'Expected response to be a <301: Moved Permanently>,'\
                   ' but was a <302: Found>' \
                   ' redirect to <http://test.host/posts/redirect/2>'
        assert_match expected, error.message
      end

      def test_error_message_shows_short_response_body
        @response = ActionDispatch::Response.new
        @response.status = 400
        @response.body = 'not too long'
        error = assert_raises(Minitest::Assertion) { assert_response 200 }
        expected = 'Expected response to be a <200: OK>,'\
                   ' but was a <400: Bad Request>' \
                   "\nResponse body: not too long"
        assert_match expected, error.message
      end

      def test_error_message_does_not_show_long_response_body
        @response = ActionDispatch::Response.new
        @response.status = 400
        @response.body = 'not too long' * 50
        error = assert_raises(Minitest::Assertion) { assert_response 200 }
        expected = 'Expected response to be a <200: OK>,'\
                   ' but was a <400: Bad Request>'
        assert_match expected, error.message
      end
    end
  end
end
