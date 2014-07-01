module ActionDispatch
  module Routing
    module DSL
      class AbstractScope
        # Define a route that only recognizes HTTP GET.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   get 'bacon', to: 'food#bacon'
        def get(*args, &block)
          map_method(:get, args, &block)
        end

        # Define a route that only recognizes HTTP POST.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   post 'bacon', to: 'food#bacon'
        def post(*args, &block)
          map_method(:post, args, &block)
        end

        # Define a route that only recognizes HTTP PATCH.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   patch 'bacon', to: 'food#bacon'
        def patch(*args, &block)
          map_method(:patch, args, &block)
        end

        # Define a route that only recognizes HTTP PUT.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   put 'bacon', to: 'food#bacon'
        def put(*args, &block)
          map_method(:put, args, &block)
        end

        # Define a route that only recognizes HTTP DELETE.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   delete 'broccoli', to: 'food#broccoli'
        def delete(*args, &block)
          map_method(:delete, args, &block)
        end

        protected
          def map_method(method, args, &block)
            options = args.extract_options!
            options[:via] = method
            match(*args, options, &block)
            self
          end
      end
    end
  end
end
