module ActionDispatch
  module Assertions
    # A small suite of assertions that test responses from Rails applications.
    module ResponseAssertions
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
        elsif type.is_a?(Symbol) && @response.response_code == ActionDispatch::StatusCodes::SYMBOL_TO_STATUS_CODE[type]
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

      # Asserts that the request was rendered with the appropriate template file or partials
      #
      # ==== Examples
      #
      #   # assert that the "new" view template was rendered
      #   assert_template "new"
      #
      #   # assert that the "_customer" partial was rendered twice
      #   assert_template :partial => '_customer', :count => 2
      #
      #   # assert that no partials were rendered
      #   assert_template :partial => false
      #
      def assert_template(options = {}, message = nil)
        validate_request!

        case options
         when NilClass, String
          rendered = (@controller.template.rendered[:template] || []).map { |t| t.identifier }
          msg = build_message(message,
                  "expecting <?> but rendering with <?>",
                  options, rendered.join(', '))
          assert_block(msg) do
            if options.nil?
              @controller.template.rendered[:template].blank?
            else
              rendered.any? { |t| t.match(options) }
            end
          end
        when Hash
          if expected_partial = options[:partial]
            partials = @controller.template.rendered[:partials]
            if expected_count = options[:count]
              found = partials.detect { |p, _| p.identifier.match(expected_partial) }
              actual_count = found.nil? ? 0 : found.second
              msg = build_message(message,
                      "expecting ? to be rendered ? time(s) but rendered ? time(s)",
                       expected_partial, expected_count, actual_count)
              assert(actual_count == expected_count.to_i, msg)
            else
              msg = build_message(message,
                      "expecting partial <?> but action rendered <?>",
                      options[:partial], partials.keys)
              assert(partials.keys.any? { |p| p.identifier.match(expected_partial) }, msg)
            end
          else
            assert @controller.template.rendered[:partials].empty?,
              "Expected no partials to be rendered"
          end
        end
      end

      private
        # Proxy to to_param if the object will respond to it.
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end

        def normalize_argument_to_redirection(fragment)
          after_routing = @controller.url_for(fragment)
          if after_routing =~ %r{^\w+://.*}
            after_routing
          else
            # FIXME - this should probably get removed.
            if after_routing.first != '/'
              after_routing = '/' + after_routing
            end
            @request.protocol + @request.host_with_port + after_routing
          end
        end

        def validate_request!
          unless @request.is_a?(ActionDispatch::Request)
            raise ArgumentError, "@request must be an ActionDispatch::Request"
          end
        end
    end
  end
end
