module ActionDispatch
  module IntegrationTesting
    module RequestHelpers
      # Performs a GET request with the given parameters. See +#process+ for more
      # details.
      def get(path, **args)
        process(:get, path, **args)
      end

      # Performs a POST request with the given parameters. See +#process+ for more
      # details.
      def post(path, **args)
        process(:post, path, **args)
      end

      # Performs a PATCH request with the given parameters. See +#process+ for more
      # details.
      def patch(path, **args)
        process(:patch, path, **args)
      end

      # Performs a PUT request with the given parameters. See +#process+ for more
      # details.
      def put(path, **args)
        process(:put, path, **args)
      end

      # Performs a DELETE request with the given parameters. See +#process+ for
      # more details.
      def delete(path, **args)
        process(:delete, path, **args)
      end

      # Performs a HEAD request with the given parameters. See +#process+ for more
      # details.
      def head(path, *args)
        process(:head, path, *args)
      end

      # Follow a single redirect response. If the last response was not a
      # redirect, an exception will be raised. Otherwise, the redirect is
      # performed on the location header.
      def follow_redirect!
        raise "not a redirect! #{status} #{status_message}" unless redirect?
        get(response.location)
        status
      end
    end
  end
end
