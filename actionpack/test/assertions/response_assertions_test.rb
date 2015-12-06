require 'abstract_unit'
require 'action_dispatch/testing/assertions/response'

module ActionDispatch
  module Assertions
    class ResponseAssertionsTest < ActiveSupport::TestCase
      include ResponseAssertions

      FakeResponse = Struct.new(:response_code, :location) do
        def initialize(*)
          super
          self.location ||= "http://test.example.com/posts"
        end

        [:successful, :not_found, :redirection, :server_error].each do |sym|
          define_method("#{sym}?") do
            sym == response_code
          end
        end
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

      def test_assert_response_fixnum
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

      def test_message_when_response_is_redirect_but_asserted_for_status_other_than_redirect
        @response = FakeResponse.new :redirection, "http://test.host/posts/redirect/1"
        error = assert_raises(Minitest::Assertion) do
          assert_response :success
        end

        expected = "Expected response to be a <success>, but was a redirect to <http://test.host/posts/redirect/1>"
        assert_equal expected, error.message
      end
    end
  end
end
