# frozen_string_literal: true

module ActionDispatch
  module Assertions
    # A small suite of assertions that test responses from \Rails applications.
    module ResponseAssertions
      RESPONSE_PREDICATES = { # :nodoc:
        success:  :successful?,
        missing:  :not_found?,
        redirect: :redirection?,
        error:    :server_error?,
      }

      # Asserts that the response is one of the following types:
      #
      # * <tt>:success</tt>   - Status code was in the 200-299 range
      # * <tt>:redirect</tt>  - Status code was in the 300-399 range
      # * <tt>:missing</tt>   - Status code was 404
      # * <tt>:error</tt>     - Status code was in the 500-599 range
      #
      # You can also pass an explicit status number like <tt>assert_response(501)</tt>
      # or its symbolic equivalent <tt>assert_response(:not_implemented)</tt>.
      # See +Rack::Utils::SYMBOL_TO_STATUS_CODE+ for a full list.
      #
      #   # Asserts that the response was a redirection
      #   assert_response :redirect
      #
      #   # Asserts that the response code was status code 401 (unauthorized)
      #   assert_response 401
      def assert_response(type, message = nil)
        message ||= generate_response_message(type)

        if RESPONSE_PREDICATES.key?(type)
          assert @response.public_send(RESPONSE_PREDICATES[type]), message
        else
          assert_equal AssertionResponse.new(type).code, @response.response_code, message
        end
      end

      # Asserts that the response is a redirect to a URL matching the given options.
      #
      #   # Asserts that the redirection was to the "index" action on the WeblogController
      #   assert_redirected_to controller: "weblog", action: "index"
      #
      #   # Asserts that the redirection was to the named route login_url
      #   assert_redirected_to login_url
      #
      #   # Asserts that the redirection was to the URL for @customer
      #   assert_redirected_to @customer
      #
      #   # Asserts that the redirection matches the regular expression
      #   assert_redirected_to %r(\Ahttp://example.org)
      #
      #   # Asserts that the redirection has the HTTP status code 301 (Moved
      #   # Permanently).
      #   assert_redirected_to "/some/path", status: :moved_permanently
      def assert_redirected_to(url_options = {}, options = {}, message = nil)
        options, message = {}, options unless options.is_a?(Hash)

        status = options[:status] || :redirect
        assert_response(status, message)
        return true if url_options === @response.location

        redirect_is       = normalize_argument_to_redirection(@response.location)
        redirect_expected = normalize_argument_to_redirection(url_options)

        message ||= "Expected response to be a redirect to <#{redirect_expected}> but was a redirect to <#{redirect_is}>"
        assert_operator redirect_expected, :===, redirect_is, message
      end

      private
        # Proxy to to_param if the object will respond to it.
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end

        def normalize_argument_to_redirection(fragment)
          if Regexp === fragment
            fragment
          else
            handle = @controller || ActionController::Redirecting
            handle._compute_redirect_to_location(@request, fragment)
          end
        end

        def generate_response_message(expected, actual = @response.response_code)
          (+"Expected response to be a <#{code_with_name(expected)}>,"\
          " but was a <#{code_with_name(actual)}>").concat(location_if_redirected).concat(response_body_if_short)
        end

        def response_body_if_short
          return "" if @response.body.size > 500
          "\nResponse body: #{@response.body}"
        end

        def location_if_redirected
          return "" unless @response.redirection? && @response.location.present?
          location = normalize_argument_to_redirection(@response.location)
          " redirect to <#{location}>"
        end

        def code_with_name(code_or_name)
          if RESPONSE_PREDICATES.value?("#{code_or_name}?".to_sym)
            code_or_name = RESPONSE_PREDICATES.invert["#{code_or_name}?".to_sym]
          end

          AssertionResponse.new(code_or_name).code_and_name
        end
    end
  end
end
