# frozen_string_literal: true

require "securerandom"
require "active_support/core_ext/string/access"

module ActionDispatch
  # Makes a unique request id available to the +action_dispatch.request_id+ env variable (which is then accessible
  # through <tt>ActionDispatch::Request#request_id</tt> or the alias <tt>ActionDispatch::Request#uuid</tt>) and sends
  # the same id to the client via the X-Request-Id header.
  #
  # The unique request id is either based on the X-Request-Id header in the request, which would typically be generated
  # by a firewall, load balancer, or the web server, or, if this header is not available, a random uuid. If the
  # header is accepted from the outside world, we sanitize it to a max of 255 chars and alphanumeric and dashes only.
  #
  # The unique request id can be used to trace a request end-to-end and would typically end up being part of log files
  # from multiple pieces of the stack.
  class RequestId
    def initialize(app, header:)
      @app = app
      @header = header
    end

    def call(env)
      req = ActionDispatch::Request.new env
      req.request_id = make_request_id(req.headers[@header])
      @app.call(env).tap { |_status, headers, _body| headers[@header] = req.request_id }
    end

    private
      def make_request_id(request_id)
        if request_id.presence
          request_id.gsub(/[^\w\-@]/, "").first(255)
        else
          internal_request_id
        end
      end

      def internal_request_id
        SecureRandom.uuid
      end
  end
end
