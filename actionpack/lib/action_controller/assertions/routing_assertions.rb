module ActionController
  module Assertions
    module RoutingAssertions
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
      
          generated_path, extra_keys = ActionController::Routing::Routes.generate_extras(options, defaults)
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
    end
  end
end