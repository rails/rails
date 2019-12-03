# frozen_string_literal: true

require "securerandom"
require "active_support/core_ext/string/access"

module ActionDispatch
  # Makes a unique request id available to the +action_dispatch.request_id+ env variable (which is then accessible
  # through <tt>ActionDispatch::Request#request_id</tt> or the alias <tt>ActionDispatch::Request#uuid</tt>) and sends
  # the same id to the client via the +http_header+ which default value is X-Request-Id.
  #
  # The unique request id is either based on the +http_header+ in the request, which would typically be generated
  # by a firewall, load balancer, or the web server, or, if this header is not available, a random uuid. If the
  # header is accepted from the outside world, we sanitize it to a max of 255 chars and alphanumeric and dashes only.
  #
  # The unique request id can be used to trace a request end-to-end and would typically end up being part of log files
  # from multiple pieces of the stack.
  class RequestId
    def initialize(app, http_header: nil, generator: nil)
      @http_header = http_header || "X-Request-Id"
      @http_header_key = http_header_key(@http_header)
      @generator = generator || SecureRandom.method(:uuid)
      @app = app
    end

    def call(env)
      req = ActionDispatch::Request.new(env)
      req.request_id = make_request_id(req.get_header(@http_header_key))
      @app.call(env).tap { |_status, headers, _body| headers[@http_header] = req.request_id }
    end

    private
      def make_request_id(request_id)
        if request_id.presence
          request_id.gsub(/[^\w\-@]/, "").first(255)
        else
          @generator.call
        end
      end

      def http_header_key(header)
        "HTTP_#{header.upcase.tr("-", "_")}"
      end
  end
end
