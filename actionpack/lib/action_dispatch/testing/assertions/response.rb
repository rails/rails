
module ActionDispatch
  module Assertions
    # A small suite of assertions that test responses from \Rails applications.
    module ResponseAssertions
      # Asserts that the response is one of the following types:
      #
      # * <tt>:success</tt>   - Status code was in the 200-299 range
      # * <tt>:redirect</tt>  - Status code was in the 300-399 range
      # * <tt>:missing</tt>   - Status code was 404
      # * <tt>:error</tt>     - Status code was in the 500-599 range
      #
      # You can also pass an explicit status number like <tt>assert_response(501)</tt>
      # or its symbolic equivalent <tt>assert_response(:not_implemented)</tt>.
      # See Rack::Utils::SYMBOL_TO_STATUS_CODE for a full list.
      #
      #   # assert that the response was a redirection
      #   assert_response :redirect
      #
      #   # assert that the response code was status code 401 (unauthorized)
      #   assert_response 401
      def assert_response(type, message = nil)
        message ||= "Expected response to be a <#{type}>, but was <#{@response.response_code}>"

        if Symbol === type
          if [:success, :missing, :redirect, :error].include?(type)
            assert @response.send("#{type}?"), message
          else
            code = Rack::Utils::SYMBOL_TO_STATUS_CODE[type]
            assert_equal code, @response.response_code, message
          end
        else
          assert_equal type, @response.response_code, message
        end
      end

      # Assert that the redirection options passed in match those of the redirect called in the latest action.
      # This match can be partial, such that <tt>assert_redirected_to(:controller => "weblog")</tt> will also
      # match the redirection of <tt>redirect_to(:controller => "weblog", :action => "show")</tt> and so on.
      #
      #   # assert that the redirection was to the "index" action on the WeblogController
      #   assert_redirected_to :controller => "weblog", :action => "index"
      #
      #   # assert that the redirection was to the named route login_url
      #   assert_redirected_to login_url
      #
      #   # assert that the redirection was to the url for @customer
      #   assert_redirected_to @customer
      #
      #   # asserts that the redirection matches the regular expression
      #   assert_redirected_to %r(\Ahttp://example.org)
      def assert_redirected_to(options = {}, message=nil)
        assert_response(:redirect, message)
        return true if options === @response.location

        redirect_is       = normalize_argument_to_redirection(@response.location)
        redirect_expected = normalize_argument_to_redirection(options)

        message ||= "Expected response to be a redirect to <#{redirect_expected}> but was a redirect to <#{redirect_is}>"
        assert_operator redirect_expected, :===, redirect_is, message
      end

      private
        # Proxy to to_param if the object will respond to it.
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end

        def normalize_argument_to_redirection(fragment)
          normalized = case fragment
            when Regexp
              fragment
            when %r{^\w[A-Za-z\d+.-]*:.*}
              fragment
            when String
              @request.protocol + @request.host_with_port + fragment
            when :back
              raise RedirectBackError unless refer = @request.headers["Referer"]
              refer
            else
              @controller.url_for(fragment)
            end

          normalized.respond_to?(:delete) ? normalized.delete("\0\r\n") : normalized
        end
    end
  end
end
