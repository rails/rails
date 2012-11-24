require 'stringio'
require 'uri'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/try'
require 'rack/test'

module ActionDispatch
  module Testing #:nodoc:
    module RequestHelpers
      # Performs a GET request with the given parameters.
      #
      # - +path+: The URI (as a String) on which you want to perform a GET
      #   request.
      # - +parameters+: The HTTP parameters that you want to pass. This may
      #   be +nil+,
      #   a Hash, or a String that is appropriately encoded
      #   (<tt>application/x-www-form-urlencoded</tt> or
      #   <tt>multipart/form-data</tt>).
      # - +headers+: Additional headers to pass, as a Hash. The headers will be
      #   merged into the Rack env hash.
      #
      # This method returns a Response object, which one can use to
      # inspect the details of the response. Furthermore, if this method was
      # called from an ActionDispatch::TestCase object, then that
      # object's <tt>@response</tt> instance variable will point to the same
      # response object.
      #
      # You can also perform POST, PATCH, PUT, DELETE, and HEAD requests with
      # +#post+, +#patch+, +#put+, +#delete+, and +#head+.
      def get(path, parameters = nil, headers = nil)
        process :get, path, parameters, headers
      end

      # Performs a POST request with the given parameters. See +#get+ for more
      # details.
      def post(path, parameters = nil, headers = nil)
        process :post, path, parameters, headers
      end

      # Performs a PATCH request with the given parameters. See +#get+ for more
      # details.
      def patch(path, parameters = nil, headers = nil)
        process :patch, path, parameters, headers
      end

      # Performs a PUT request with the given parameters. See +#get+ for more
      # details.
      def put(path, parameters = nil, headers = nil)
        process :put, path, parameters, headers
      end

      # Performs a DELETE request with the given parameters. See +#get+ for
      # more details.
      def delete(path, parameters = nil, headers = nil)
        process :delete, path, parameters, headers
      end

      # Performs a HEAD request with the given parameters. See +#get+ for more
      # details.
      def head(path, parameters = nil, headers = nil)
        process :head, path, parameters, headers
      end

      # Performs a OPTIONS request with the given parameters. See +#get+ for
      # more details.
      def options(path, parameters = nil, headers = nil)
        process :options, path, parameters, headers
      end

      # Performs an XMLHttpRequest request with the given parameters, mirroring
      # a request from the Prototype library.
      #
      # The request_method is +:get+, +:post+, +:patch+, +:put+, +:delete+ or
      # +:head+; the parameters are +nil+, a hash, or a url-encoded or multipart
      # string; the headers are a hash.
      def xml_http_request(request_method, path, parameters = nil, headers = nil)
        headers ||= {}
        headers['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
        headers['HTTP_ACCEPT'] ||= [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
        process(request_method, path, parameters, headers)
      end
      alias xhr :xml_http_request

      # Follow a single redirect response. If the last response was not a
      # redirect, an exception will be raised. Otherwise, the redirect is
      # performed on the location header.
      def follow_redirect!
        raise "not a redirect! #{status} #{status_message}" unless redirect?
        get(response.location)
        status
      end

      # Performs a request using the specified method, following any subsequent
      # redirect. Note that the redirects are followed until the response is
      # not a redirect--this means you may run into an infinite loop if your
      # redirect loops back to itself.
      def request_via_redirect(http_method, path, parameters = nil, headers = nil)
        process(http_method, path, parameters, headers)
        follow_redirect! while redirect?
        status
      end

      # Performs a GET request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def get_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:get, path, parameters, headers)
      end

      # Performs a POST request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def post_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:post, path, parameters, headers)
      end

      # Performs a PATCH request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def patch_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:patch, path, parameters, headers)
      end

      # Performs a PUT request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def put_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:put, path, parameters, headers)
      end

      # Performs a DELETE request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def delete_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:delete, path, parameters, headers)
      end
    end
  end
end
