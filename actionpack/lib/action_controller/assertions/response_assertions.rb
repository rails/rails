module ActionController
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
      # See ActionController::StatusCodes for a full list.
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
        clean_backtrace do
          if [ :success, :missing, :redirect, :error ].include?(type) && @response.send("#{type}?")
            assert_block("") { true } # to count the assertion
          elsif type.is_a?(Fixnum) && @response.response_code == type
            assert_block("") { true } # to count the assertion
          elsif type.is_a?(Symbol) && @response.response_code == ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE[type]
            assert_block("") { true } # to count the assertion
          else
            if @response.error?
              exception = @response.template.instance_variable_get(:@exception)
              exception_message = exception && exception.message
              assert_block(build_message(message, "Expected response to be a <?>, but was <?>\n<?>", type, @response.response_code, exception_message.to_s)) { false }
            else
              assert_block(build_message(message, "Expected response to be a <?>, but was <?>", type, @response.response_code)) { false }
            end
          end
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
        clean_backtrace do
          assert_response(:redirect, message)
          return true if options == @response.redirected_to

          # Support partial arguments for hash redirections
          if options.is_a?(Hash) && @response.redirected_to.is_a?(Hash)
            if options.all? {|(key, value)| @response.redirected_to[key] == value}
              callstack = caller.dup
              callstack.slice!(0, 2)
              ::ActiveSupport::Deprecation.warn("Using assert_redirected_to with partial hash arguments is deprecated. Specify the full set arguments instead", callstack)
              return true
            end
          end

          redirected_to_after_normalisation = normalize_argument_to_redirection(@response.redirected_to)
          options_after_normalisation       = normalize_argument_to_redirection(options)

          if redirected_to_after_normalisation != options_after_normalisation
            flunk "Expected response to be a redirect to <#{options_after_normalisation}> but was a redirect to <#{redirected_to_after_normalisation}>"
          end
        end
      end

      # Asserts that the request was rendered with the appropriate template file or partials
      #
      # ==== Examples
      #
      #   # assert that the "new" view template was rendered
      #   assert_template "new"
      #
      #   # assert that the "new" view template was rendered with Symbol
      #   assert_template :new
      #
      #   # assert that the "_customer" partial was rendered twice
      #   assert_template :partial => '_customer', :count => 2
      #
      #   # assert that no partials were rendered
      #   assert_template :partial => false
      #
      def assert_template(options = {}, message = nil)
        clean_backtrace do
          case options
           when NilClass, String, Symbol
            rendered = @response.rendered[:template].to_s
            msg = build_message(message,
                    "expecting <?> but rendering with <?>",
                    options, rendered)
            assert_block(msg) do
              if options.nil?
                @response.rendered[:template].blank?
              else
                rendered.to_s.match(options.to_s)
              end
            end
          when Hash
            if expected_partial = options[:partial]
              partials = @response.rendered[:partials]
              if expected_count = options[:count]
                found = partials.detect { |p, _| p.to_s.match(expected_partial) }
                actual_count = found.nil? ? 0 : found.second
                msg = build_message(message,
                        "expecting ? to be rendered ? time(s) but rendered ? time(s)",
                         expected_partial, expected_count, actual_count)
                assert(actual_count == expected_count.to_i, msg)
              else
                msg = build_message(message,
                        "expecting partial <?> but action rendered <?>",
                        options[:partial], partials.keys)
                assert(partials.keys.any? { |p| p.to_s.match(expected_partial) }, msg)
              end
            else
              assert @response.rendered[:partials].empty?,
                "Expected no partials to be rendered"
            end
          else
            raise ArgumentError  
          end
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
              if fragment !~ /^\//
                ActiveSupport::Deprecation.warn "Omitting the leading slash on a path with assert_redirected_to is deprecated. Use '/#{fragment}' instead.", caller(2)
                fragment = "/#{fragment}"
              end
              @request.protocol + @request.host_with_port + fragment
            end
          when :back
            raise RedirectBackError unless refer = @request.headers["Referer"]
            refer
          else
            @controller.url_for(fragment)
          end.gsub(/[\r\n]/, '')
        end
    end
  end
end
