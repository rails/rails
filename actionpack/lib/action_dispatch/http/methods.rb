module ActionDispatch
  module Http
    module Methods
      # List of HTTP request methods from the following RFCs:
      # Hypertext Transfer Protocol -- HTTP/1.1 (http://www.ietf.org/rfc/rfc2616.txt)
      # HTTP Extensions for Distributed Authoring -- WEBDAV (http://www.ietf.org/rfc/rfc2518.txt)
      # Versioning Extensions to WebDAV (http://www.ietf.org/rfc/rfc3253.txt)
      # Ordered Collections Protocol (WebDAV) (http://www.ietf.org/rfc/rfc3648.txt)
      # Web Distributed Authoring and Versioning (WebDAV) Access Control Protocol (http://www.ietf.org/rfc/rfc3744.txt)
      # Web Distributed Authoring and Versioning (WebDAV) SEARCH (http://www.ietf.org/rfc/rfc5323.txt)
      # Calendar Extensions to WebDAV (http://www.ietf.org/rfc/rfc4791.txt)
      # PATCH Method for HTTP (http://www.ietf.org/rfc/rfc5789.txt)
      RFC2616 = %w(OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT)
      RFC2518 = %w(PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK)
      RFC3253 = %w(VERSION-CONTROL REPORT CHECKOUT CHECKIN UNCHECKOUT MKWORKSPACE UPDATE LABEL MERGE BASELINE-CONTROL MKACTIVITY)
      RFC3648 = %w(ORDERPATCH)
      RFC3744 = %w(ACL)
      RFC5323 = %w(SEARCH)
      RFC4791 = %w(MKCALENDAR)
      RFC5789 = %w(PATCH)

      HTTP_METHODS = RFC2616 + RFC2518 + RFC3253 + RFC3648 + RFC3744 + RFC5323 + RFC4791 + RFC5789

      HTTP_METHOD_LOOKUP = {}

      # Populate the HTTP method lookup cache
      HTTP_METHODS.each { |method|
        HTTP_METHOD_LOOKUP[method] = method.underscore.to_sym
      }

      # Returns the HTTP \method that the application should see.
      # In the case where the \method was overridden by a middleware
      # (for instance, if a HEAD request was converted to a GET,
      # or if a _method parameter was used to determine the \method
      # the application should use), this \method returns the overridden
      # value, not the original.
      def request_method
        @request_method ||= check_method(env["REQUEST_METHOD"])
      end

      def request_method=(request_method) #:nodoc:
        if check_method(request_method)
          @request_method = env["REQUEST_METHOD"] = request_method
        end
      end

      # Returns a symbol form of the #request_method
      def request_method_symbol
        HTTP_METHOD_LOOKUP[request_method]
      end

      # Returns the original value of the environment's REQUEST_METHOD,
      # even if it was overridden by middleware. See #request_method for
      # more information.
      def method
        @method ||= check_method(env["rack.methodoverride.original_method"] || env['REQUEST_METHOD'])
      end

      # Returns a symbol form of the #method
      def method_symbol
        HTTP_METHOD_LOOKUP[method]
      end

      # Is this a GET (or HEAD) request?
      # Equivalent to <tt>request.request_method_symbol == :get</tt>.
      def get?
        HTTP_METHOD_LOOKUP[request_method] == :get
      end

      # Is this a POST request?
      # Equivalent to <tt>request.request_method_symbol == :post</tt>.
      def post?
        HTTP_METHOD_LOOKUP[request_method] == :post
      end

      # Is this a PATCH request?
      # Equivalent to <tt>request.request_method == :patch</tt>.
      def patch?
        HTTP_METHOD_LOOKUP[request_method] == :patch
      end

      # Is this a PUT request?
      # Equivalent to <tt>request.request_method_symbol == :put</tt>.
      def put?
        HTTP_METHOD_LOOKUP[request_method] == :put
      end

      # Is this a DELETE request?
      # Equivalent to <tt>request.request_method_symbol == :delete</tt>.
      def delete?
        HTTP_METHOD_LOOKUP[request_method] == :delete
      end

      # Is this a HEAD request?
      # Equivalent to <tt>request.request_method_symbol == :head</tt>.
      def head?
        HTTP_METHOD_LOOKUP[request_method] == :head
      end

      # Is this a TRACE request?
      # Equivalent to <tt>request.request_method_symbol == :trace</tt>.
      def trace?
        HTTP_METHOD_LOOKUP[request_method] == :trace
      end
    end
  end
end