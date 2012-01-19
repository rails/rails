module ActionDispatch
  module Routing
    module HttpHelpers
      # Define a route that only recognizes HTTP GET.
      # For supported arguments, see <tt>Base#match</tt>.
      #
      # Example:
      #
      # get 'bacon', :to => 'food#bacon'
      def get(*args, &block)
        map_method(:get, *args, &block)
      end

      # Define a route that only recognizes HTTP POST.
      # For supported arguments, see <tt>Base#match</tt>.
      #
      # Example:
      #
      # post 'bacon', :to => 'food#bacon'
      def post(*args, &block)
        map_method(:post, *args, &block)
      end

      # Define a route that only recognizes HTTP PUT.
      # For supported arguments, see <tt>Base#match</tt>.
      #
      # Example:
      #
      # put 'bacon', :to => 'food#bacon'
      def put(*args, &block)
        map_method(:put, *args, &block)
      end

      # Define a route that only recognizes HTTP PUT.
      # For supported arguments, see <tt>Base#match</tt>.
      #
      # Example:
      #
      # delete 'broccoli', :to => 'food#broccoli'
      def delete(*args, &block)
        map_method(:delete, *args, &block)
      end

      private
        def map_method(method, *args, &block)
          options = args.extract_options!
          options[:via] = method
          args.push(options)
          match(*args, &block)
          self
        end
    end
  end
end
