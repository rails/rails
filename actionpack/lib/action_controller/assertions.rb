require 'test/unit'
require 'test/unit/assertions'
require 'rexml/document'

module Test #:nodoc:
  module Unit #:nodoc:
    # In addition to these specific assertions, you also have easy access to various collections that the regular test/unit assertions
    # can be used against. These collections are:
    #
    # * assigns: Instance variables assigned in the action that's available for the view.
    # * session: Objects being saved in the session.
    # * flash: The flash objects being currently in the session.
    # * cookies: Cookies being sent to the user on this request.
    # 
    # These collections can be used just like any other hash:
    #
    #   assert_not_nil assigns[:person] # makes sure that a @person instance variable was set
    #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
    #   assert flash.empty? # makes sure that there's nothing in the flash
    #
    # On top of the collections, you have the complete url that a given action redirected to available in redirect_to_url.
    #
    # For redirects within the same controller, you can even call follow_redirect and the redirect will be follow triggering another
    # action call which can then be asserted against.
    module Assertions
      # Asserts that the response is one of the following types:
      # 
      # * <tt>:success</tt>: Status code was 200
      # * <tt>:redirect</tt>: Status code was in the 300-399 range
      # * <tt>:missing</tt>: Status code was 404
      # * <tt>:error</tt>:  Status code was in the 500-599 range
      #
      # You can also pass an explicit status code number as the type, like assert_response(501)
      def assert_response(type, message = nil)
        if [ :success, :missing, :redirect, :error ].include?(type) && @response.send("#{type}?")
          assert_block("") { true } # to count the assertion
        elsif type.is_a?(Fixnum) && @response.response_code == type
          assert_block("") { true } # to count the assertion
        else
          assert_block(build_message(message, "Expected response to be a <?>, but was <?>", type, @response.response_code)) { false }
        end
      end

      # Assert that the redirection options passed in match those of the redirect called in the latest action. This match can be partial,
      # such at assert_redirected_to(:controller => "weblog") will also match the redirection of 
      # redirect_to(:controller => "weblog", :action => "show") and so on.
      def assert_redirected_to(options = {}, message=nil)
        assert_redirect(message)

        msg = build_message(message, "response is not a redirection to all of the options supplied (redirection is <?>)", @response.redirected_to)
        assert_block(msg) do
          if options.is_a?(Symbol)
            @response.redirected_to == options
          else
            options.keys.all? do |k| 
              options[k] == (@response.redirected_to[k].respond_to?(:to_param) ? @response.redirected_to[k].to_param : @response.redirected_to[k] if @response.redirected_to[k])
            end
          end
        end
      end

      # Asserts that the request was rendered with the appropriate template file
      def assert_template(expected=nil, message=nil)
        rendered = expected ? @response.rendered_file(!expected.include?('/')) : @response.rendered_file
        msg = build_message(message, "expecting <?> but rendering with <?>", expected, rendered)
        assert_block(msg) do
          if expected.nil?
            @response.rendered_with_file?
          else
            expected == rendered
          end
        end
      end

      alias_method :assert_rendered_file, :assert_template #:nodoc:
      
      # -- routing assertions --------------------------------------------------

      # Asserts that the routing of the given path is handled correctly and that the parsed options match.
      def assert_recognizes(expected_options, path, extras={}, message=nil)
        # Load routes.rb if it hasn't been loaded.
        ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 
      
        # Assume given controller
        request = ActionController::TestRequest.new({}, {}, nil)
        request.path = path
        ActionController::Routing::Routes.recognize!(request)
      
        expected_options = expected_options.clone
        extras.each_key { |key| expected_options.delete key } unless extras.nil?
      
        msg = build_message(message, "The recognized options <?> did not match <?>", 
            request.path_parameters, expected_options)
        assert_block(msg) { request.path_parameters == expected_options }
      end

      # Asserts that the provided options can be used to generate the provided path.
      def assert_generates(expected_path, options, defaults={}, extras = {}, message=nil)
        # Load routes.rb if it hasn't been loaded.
        ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 
      
        # Assume given controller
        request = ActionController::TestRequest.new({}, {}, nil)
        request.path_parameters = (defaults or {}).clone
        request.path_parameters[:controller] ||= options[:controller]
      
        generated_path, found_extras = ActionController::Routing::Routes.generate(options, request)
        generated_path = generated_path.join('/')
        msg = build_message(message, "found extras <?>, not <?>", found_extras, extras)
        assert_block(msg) { found_extras == extras }
      
        msg = build_message(message, "The generated path <?> did not match <?>", generated_path, 
            expected_path)
        assert_block(msg) { expected_path == generated_path }
      end

      # asserts that path and options match both ways, in other words, the URL generated from 
      # options is same as path, and also that the options recognized from path are same as options
      def assert_routing(path, options, defaults={}, extras={}, message=nil)
        assert_recognizes(options, path, extras, message)
        assert_generates(path, options, defaults, extras, message)
      end
    end
  end
end