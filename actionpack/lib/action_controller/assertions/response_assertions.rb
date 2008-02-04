require 'rexml/document'
require 'html/document'

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
              assert_block(build_message(message, "Expected response to be a <?>, but was <?>\n<?>", type, @response.response_code, @response.template.instance_variable_get(:@exception).message)) { false }
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
      def assert_redirected_to(options = {}, message=nil)
        clean_backtrace do
          assert_response(:redirect, message)
          return true if options == @response.redirected_to
          ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty?

          begin
            url  = {}
            original = { :expected => options, :actual => @response.redirected_to.is_a?(Symbol) ? @response.redirected_to : @response.redirected_to.dup }
            original.each do |key, value|
              if value.is_a?(Symbol)
                value = @controller.respond_to?(value, true) ? @controller.send(value) : @controller.send("hash_for_#{value}_url")
              end

              unless value.is_a?(Hash)
                request = case value
                  when NilClass    then nil
                  when /^\w+:\/\// then recognized_request_for(%r{^(\w+://.*?(/|$|\?))(.*)$} =~ value ? $3 : nil)
                  else                  recognized_request_for(value)
                end
                value = request.path_parameters if request
              end

              if value.is_a?(Hash) # stringify 2 levels of hash keys
                if name = value.delete(:use_route)
                  route = ActionController::Routing::Routes.named_routes[name]
                  value.update(route.parameter_shell)
                end

                value.stringify_keys!
                value.values.select { |v| v.is_a?(Hash) }.collect { |v| v.stringify_keys! }
                if key == :expected && value['controller'] == @controller.controller_name && original[:actual].is_a?(Hash)
                  original[:actual].stringify_keys!
                  value.delete('controller') if original[:actual]['controller'].nil? || original[:actual]['controller'] == value['controller']
                end
              end

              if value.respond_to?(:[]) && value['controller']
                value['controller'] = value['controller'].to_s
                if key == :actual && value['controller'].first != '/' && !value['controller'].include?('/')
                  new_controller_path = ActionController::Routing.controller_relative_to(value['controller'], @controller.class.controller_path)
                  value['controller'] = new_controller_path if value['controller'] != new_controller_path && ActionController::Routing.possible_controllers.include?(new_controller_path) && @response.redirected_to.is_a?(Hash)
                end
                value['controller'] = value['controller'][1..-1] if value['controller'].first == '/' # strip leading hash
              end
              url[key] = value
            end

            @response_diff = url[:actual].diff(url[:expected]) if url[:actual]
            msg = build_message(message, "expected a redirect to <?>, found one to <?>, a difference of <?> ", url[:expected], url[:actual], @response_diff)

            assert_block(msg) do
              url[:expected].keys.all? do |k|
                if k == :controller then url[:expected][k] == ActionController::Routing.controller_relative_to(url[:actual][k], @controller.class.controller_path)
                else parameterize(url[:expected][k]) == parameterize(url[:actual][k])
                end
              end
            end
          rescue ActionController::RoutingError # routing failed us, so match the strings only.
            msg = build_message(message, "expected a redirect to <?>, found one to <?>", options, @response.redirect_url)
            url_regexp = %r{^(\w+://.*?(/|$|\?))(.*)$}
            eurl, epath, url, path = [options, @response.redirect_url].collect do |url|
              u, p = (url_regexp =~ url) ? [$1, $3] : [nil, url]
              [u, (p.first == '/') ? p : '/' + p]
            end.flatten

            assert_equal(eurl, url, msg) if eurl && url
            assert_equal(epath, path, msg) if epath && path
          end
        end
      end

      # Asserts that the request was rendered with the appropriate template file.
      #
      # ==== Examples
      #
      #   # assert that the "new" view template was rendered
      #   assert_template "new"
      #
      def assert_template(expected = nil, message=nil)
        clean_backtrace do
          rendered = expected ? @response.rendered_file(!expected.include?('/')) : @response.rendered_file
          msg = build_message(message, "expecting <?> but rendering with <?>", expected, rendered)
          assert_block(msg) do
            if expected.nil?
              !@response.rendered_with_file?
            else
              expected == rendered
            end
          end
        end
      end

      private
        # Recognizes the route for a given path.
        def recognized_request_for(path, request_method = nil)
          path = "/#{path}" unless path.first == '/'

          # Assume given controller
          request = ActionController::TestRequest.new({}, {}, nil)
          request.env["REQUEST_METHOD"] = request_method.to_s.upcase if request_method
          request.path   = path

          ActionController::Routing::Routes.recognize(request)
          request
        end

        # Proxy to to_param if the object will respond to it.
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end
    end
  end
end
