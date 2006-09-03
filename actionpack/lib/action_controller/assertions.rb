require 'test/unit'
require 'test/unit/assertions'
require 'rexml/document'
require File.dirname(__FILE__) + "/vendor/html-scanner/html/document"

module Test #:nodoc:
  module Unit #:nodoc:
    # In addition to these specific assertions, you also have easy access to various collections that the regular test/unit assertions
    # can be used against. These collections are:
    #
    # * assigns: Instance variables assigned in the action that are available for the view.
    # * session: Objects being saved in the session.
    # * flash: The flash objects currently in the session.
    # * cookies: Cookies being sent to the user on this request.
    # 
    # These collections can be used just like any other hash:
    #
    #   assert_not_nil assigns(:person) # makes sure that a @person instance variable was set
    #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
    #   assert flash.empty? # makes sure that there's nothing in the flash
    #
    # For historic reasons, the assigns hash uses string-based keys. So assigns[:person] won't work, but assigns["person"] will. To
    # appease our yearning for symbols, though, an alternative accessor has been deviced using a method call instead of index referencing.
    # So assigns(:person) will work just like assigns["person"], but again, assigns[:person] will not work.
    #
    # On top of the collections, you have the complete url that a given action redirected to available in redirect_to_url.
    #
    # For redirects within the same controller, you can even call follow_redirect and the redirect will be followed, triggering another
    # action call which can then be asserted against.
    #
    # == Manipulating the request collections
    #
    # The collections described above link to the response, so you can test if what the actions were expected to do happened. But
    # sometimes you also want to manipulate these collections in the incoming request. This is really only relevant for sessions
    # and cookies, though. For sessions, you just do:
    #
    #   @request.session[:key] = "value"
    #
    # For cookies, you need to manually create the cookie, like this:
    #
    #   @request.cookies["key"] = CGI::Cookie.new("key", "value")
    #
    # == Testing named routes
    #
    # If you're using named routes, they can be easily tested using the original named routes methods straight in the test case.
    # Example: 
    #
    #  assert_redirected_to page_url(:title => 'foo')
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
        clean_backtrace do
          if [ :success, :missing, :redirect, :error ].include?(type) && @response.send("#{type}?")
            assert_block("") { true } # to count the assertion
          elsif type.is_a?(Fixnum) && @response.response_code == type
            assert_block("") { true } # to count the assertion
          else
            assert_block(build_message(message, "Expected response to be a <?>, but was <?>", type, @response.response_code)) { false }
          end               
        end
      end

      # Assert that the redirection options passed in match those of the redirect called in the latest action. This match can be partial,
      # such that assert_redirected_to(:controller => "weblog") will also match the redirection of 
      # redirect_to(:controller => "weblog", :action => "show") and so on.
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
                if key == :actual && value['controller'].first != '/' && !value['controller'].include?('/')
                  value['controller'] = ActionController::Routing.controller_relative_to(value['controller'], @controller.class.controller_path) 
                end
                value['controller'] = value['controller'][1..-1] if value['controller'].first == '/' # strip leading hash
              end
              url[key] = value
            end
            

            @response_diff = url[:expected].diff(url[:actual]) if url[:actual]
            msg = build_message(message, "response is not a redirection to all of the options supplied (redirection is <?>), difference: <?>", 
                                url[:actual], @response_diff)
            
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

      # Asserts that the routing of the given path was handled correctly and that the parsed options match.
      #
      #   assert_recognizes({:controller => 'items', :action => 'index'}, 'items')
      #
      # Pass a hash in the second argument to specify the request method.  This is useful for routes
      # requiring a specific method.
      #
      #   assert_recognizes({:controller => 'items', :action => 'create'}, {:path => 'items', :method => :post})
      #
      def assert_recognizes(expected_options, path, extras={}, message=nil)
        if path.is_a? Hash
          request_method = path[:method]
          path           = path[:path]
        else
          request_method = nil
        end

        clean_backtrace do 
          ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 
          request = recognized_request_for(path, request_method)
      
          expected_options = expected_options.clone
          extras.each_key { |key| expected_options.delete key } unless extras.nil?
      
          expected_options.stringify_keys!
          routing_diff = expected_options.diff(request.path_parameters)
          msg = build_message(message, "The recognized options <?> did not match <?>, difference: <?>", 
              request.path_parameters, expected_options, expected_options.diff(request.path_parameters))
          assert_block(msg) { request.path_parameters == expected_options }
        end
      end

      # Asserts that the provided options can be used to generate the provided path.
      def assert_generates(expected_path, options, defaults={}, extras = {}, message=nil)
        clean_backtrace do 
          expected_path = "/#{expected_path}" unless expected_path[0] == ?/
          # Load routes.rb if it hasn't been loaded.
          ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 
      
          generated_path, extra_keys = ActionController::Routing::Routes.generate_extras(options, extras)
          found_extras = options.reject {|k, v| ! extra_keys.include? k}

          msg = build_message(message, "found extras <?>, not <?>", found_extras, extras)
          assert_block(msg) { found_extras == extras }
      
          msg = build_message(message, "The generated path <?> did not match <?>", generated_path, 
              expected_path)
          assert_block(msg) { expected_path == generated_path }
        end
      end

      # Asserts that path and options match both ways; in other words, the URL generated from 
      # options is the same as path, and also that the options recognized from path are the same as options
      def assert_routing(path, options, defaults={}, extras={}, message=nil)
        assert_recognizes(options, path, extras, message)
        
        controller, default_controller = options[:controller], defaults[:controller] 
        if controller && controller.include?(?/) && default_controller && default_controller.include?(?/)
          options[:controller] = "/#{controller}"
        end
         
        assert_generates(path, options, defaults, extras, message)
      end

      # test 2 html strings to be equivalent, i.e. identical up to reordering of attributes
      def assert_dom_equal(expected, actual, message="")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom = HTML::Document.new(actual).root
          full_message = build_message(message, "<?> expected to be == to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom == actual_dom }
        end
      end
      
      # negated form of +assert_dom_equivalent+
      def assert_dom_not_equal(expected, actual, message="")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom   = HTML::Document.new(actual).root
          full_message = build_message(message, "<?> expected to be != to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom != actual_dom }
        end
      end

      # ensures that the passed record is valid by active record standards. returns the error messages if not
      def assert_valid(record)
        clean_backtrace do
          assert record.valid?, record.errors.full_messages.join("\n")
        end
      end             
      
      def clean_backtrace(&block)
        yield
      rescue AssertionFailedError => e         
        path = File.expand_path(__FILE__)
        raise AssertionFailedError, e.message, e.backtrace.reject { |line| File.expand_path(line) =~ /#{path}/ }
      end
      
      private
        def recognized_request_for(path, request_method = nil)
          path = "/#{path}" unless path.first == '/'

          # Assume given controller
          request = ActionController::TestRequest.new({}, {}, nil)
          request.env["REQUEST_METHOD"] = request_method.to_s.upcase if request_method
          request.path   = path

          ActionController::Routing::Routes.recognize(request)
          request
        end
        
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end
    end
  end
end