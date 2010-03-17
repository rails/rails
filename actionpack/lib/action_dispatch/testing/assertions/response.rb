module ActionDispatch
  module Assertions
    # A small suite of assertions that test responses from Rails applications.
    module ResponseAssertions
      extend ActiveSupport::Concern

      included do
        # TODO: Need to pull in AV::Template monkey patches that track which
        # templates are rendered. assert_template should probably be part
        # of AV instead of AD.
        require 'action_view/test_case'
      end

      # Asserts that the response is one of the following types:
      #
      # * <tt>:success</tt>   - Status code was 200
      # * <tt>:redirect</tt>  - Status code was in the 300-399 range
      # * <tt>:missing</tt>   - Status code was 404
      # * <tt>:error</tt>     - Status code was in the 500-599 range
      #
      # You can also pass an explicit status number like assert_response(501)
      # or its symbolic equivalent assert_response(:not_implemented).
      # See ActionDispatch::StatusCodes for a full list.
      #
      # ==== Examples
      #
      #   # assert that the response was a redirection
      #   assert_response :redirect
      #
      #   # assert that the response code was status code 401 (unauthorized)
      #   assert_response 401
      #
      def assert_response(type, message = nil)
        validate_request!

        if [ :success, :missing, :redirect, :error ].include?(type) && @response.send("#{type}?")
          assert_block("") { true } # to count the assertion
        elsif type.is_a?(Fixnum) && @response.response_code == type
          assert_block("") { true } # to count the assertion
        elsif type.is_a?(Symbol) && @response.response_code == Rack::Utils::SYMBOL_TO_STATUS_CODE[type]
          assert_block("") { true } # to count the assertion
        else
          assert_block(build_message(message, "Expected response to be a <?>, but was <?>", type, @response.response_code)) { false }
        end
      end

      # Assert that the redirection options passed in match those of the redirect called in the latest action.
      # This match can be partial, such that assert_redirected_to(:controller => "weblog") will also
      # match the redirection of redirect_to(:controller => "weblog", :action => "show") and so on.
      #
      # ==== Examples
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
      def assert_redirected_to(options = {}, message=nil)
        validate_request!

        assert_response(:redirect, message)
        return true if options == @response.location

        redirected_to_after_normalisation = normalize_argument_to_redirection(@response.location)
        options_after_normalisation       = normalize_argument_to_redirection(options)

        if redirected_to_after_normalisation != options_after_normalisation
          flunk "Expected response to be a redirect to <#{options_after_normalisation}> but was a redirect to <#{redirected_to_after_normalisation}>"
        end
      end

      private
        # Proxy to to_param if the object will respond to it.
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end

        def normalize_argument_to_redirection(fragment)
          case fragment
          when %r{^\w[\w\d+.-]*:.*}
            fragment
          when String
            if fragment =~ %r{^\w[\w\d+.-]*:.*}
              fragment
            else
              @request.protocol + @request.host_with_port + fragment
            end
          when :back
            raise RedirectBackError unless refer = @request.headers["Referer"]
            refer
          else
            @controller.url_for(fragment)
          end.gsub(/[\r\n]/, '')
        end

        def validate_request!
          unless @request.is_a?(ActionDispatch::Request)
            raise ArgumentError, "@request must be an ActionDispatch::Request"
          end
        end
    end
  end
end
