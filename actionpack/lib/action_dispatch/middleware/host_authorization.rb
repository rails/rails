# frozen_string_literal: true

module ActionDispatch
  # = Action Dispatch \HostAuthorization
  #
  # This middleware guards from DNS rebinding attacks by explicitly permitting
  # the hosts a request can be sent to, and is passed the options set in
  # +config.host_authorization+.
  #
  # Requests can opt-out of Host Authorization with +exclude+:
  #
  #    config.host_authorization = { exclude: ->(request) { request.path =~ /healthcheck/ } }
  #
  # When a request comes to an unauthorized host, the +response_app+
  # application will be executed and rendered. If no +response_app+ is given, a
  # default one will run.
  # The default response app logs blocked host info with level 'error' and
  # responds with <tt>403 Forbidden</tt>. The body of the response contains debug info
  # if +config.consider_all_requests_local+ is set to true, otherwise the body is empty.
  class HostAuthorization
    ALLOWED_HOSTS_IN_DEVELOPMENT = [".localhost", IPAddr.new("0.0.0.0/0"), IPAddr.new("::/0")]
    PORT_REGEX = /(?::\d+)/ # :nodoc:
    SUBDOMAIN_REGEX = /(?:[a-z0-9-]+\.)/i # :nodoc:
    IPV4_HOSTNAME = /(?<host>\d+\.\d+\.\d+\.\d+)#{PORT_REGEX}?/ # :nodoc:
    IPV6_HOSTNAME = /(?<host>[a-f0-9]*:[a-f0-9.:]+)/i # :nodoc:
    IPV6_HOSTNAME_WITH_PORT = /\[#{IPV6_HOSTNAME}\]#{PORT_REGEX}/i # :nodoc:
    VALID_IP_HOSTNAME = Regexp.union( # :nodoc:
      /\A#{IPV4_HOSTNAME}\z/,
      /\A#{IPV6_HOSTNAME}\z/,
      /\A#{IPV6_HOSTNAME_WITH_PORT}\z/,
    )

    class Permissions # :nodoc:
      def initialize(hosts)
        @hosts = sanitize_hosts(hosts)
      end

      def empty?
        @hosts.empty?
      end

      def allows?(host)
        @hosts.any? do |allowed|
          if allowed.is_a?(IPAddr)
            begin
              allowed === extract_hostname(host)
            rescue
              # IPAddr#=== raises an error if you give it a hostname instead of
              # IP. Treat similar errors as blocked access.
              false
            end
          else
            allowed === host
          end
        end
      end

      private
        def sanitize_hosts(hosts)
          Array(hosts).map do |host|
            case host
            when Regexp then sanitize_regexp(host)
            when String then sanitize_string(host)
            else host
            end
          end
        end

        def sanitize_regexp(host)
          /\A#{host}#{PORT_REGEX}?\z/
        end

        def sanitize_string(host)
          if host.start_with?(".")
            /\A#{SUBDOMAIN_REGEX}?#{Regexp.escape(host[1..-1])}#{PORT_REGEX}?\z/i
          else
            /\A#{Regexp.escape host}#{PORT_REGEX}?\z/i
          end
        end

        def extract_hostname(host)
          host.slice(VALID_IP_HOSTNAME, "host") || host
        end
    end

    class DefaultResponseApp # :nodoc:
      RESPONSE_STATUS = 403

      def call(env)
        request = Request.new(env)
        format = request.xhr? ? "text/plain" : "text/html"

        log_error(request)
        response(format, response_body(request))
      end

      private
        def response_body(request)
          return "" unless request.get_header("action_dispatch.show_detailed_exceptions")

          template = DebugView.new(hosts: request.env["action_dispatch.blocked_hosts"])
          template.render(template: "rescues/blocked_host", layout: "rescues/layout")
        end

        def response(format, body)
          [RESPONSE_STATUS,
           { Rack::CONTENT_TYPE => "#{format}; charset=#{Response.default_charset}",
             Rack::CONTENT_LENGTH => body.bytesize.to_s },
           [body]]
        end

        def log_error(request)
          logger = available_logger(request)

          return unless logger

          logger.error("[#{self.class.name}] Blocked hosts: #{request.env["action_dispatch.blocked_hosts"].join(", ")}")
        end

        def available_logger(request)
          request.logger || ActionView::Base.logger
        end
    end

    def initialize(app, hosts, exclude: nil, response_app: nil)
      @app = app
      @permissions = Permissions.new(hosts)
      @exclude = exclude

      @response_app = response_app || DefaultResponseApp.new
    end

    def call(env)
      return @app.call(env) if @permissions.empty?

      request = Request.new(env)
      hosts = blocked_hosts(request)

      if hosts.empty? || excluded?(request)
        mark_as_authorized(request)
        @app.call(env)
      else
        env["action_dispatch.blocked_hosts"] = hosts
        @response_app.call(env)
      end
    end

    private
      def blocked_hosts(request)
        hosts = []

        origin_host = request.get_header("HTTP_HOST")
        hosts << origin_host unless @permissions.allows?(origin_host)

        forwarded_host = request.x_forwarded_host&.split(/,\s?/)&.last
        hosts << forwarded_host unless forwarded_host.blank? || @permissions.allows?(forwarded_host)

        hosts
      end

      def excluded?(request)
        @exclude && @exclude.call(request)
      end

      def mark_as_authorized(request)
        request.set_header("action_dispatch.authorized_host", request.host)
      end
  end
end
