# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  # # Action Dispatch SSL
  #
  # This middleware is added to the stack when `config.force_ssl = true`, and is
  # passed the options set in `config.ssl_options`. It does three jobs to enforce
  # secure HTTP requests:
  #
  # 1.  **TLS redirect**: Permanently redirects `http://` requests to `https://`
  #     with the same URL host, path, etc. Enabled by default. Set
  #     `config.ssl_options` to modify the destination URL:
  #
  #         config.ssl_options = { redirect: { host: "secure.widgets.com", port: 8080 }`
  #
  #     Or set `redirect: false` to disable redirection.
  #
  #     Requests can opt-out of redirection with `exclude`:
  #
  #         config.ssl_options = { redirect: { exclude: -> request { request.path == "/up" } } }
  #
  #     Cookies will not be flagged as secure for excluded requests.
  #
  #     When proxying through a load balancer that terminates SSL, the forwarded
  #     request will appear as though it's HTTP instead of HTTPS to the application.
  #     This makes redirects and cookie security target HTTP instead of HTTPS.
  #     To make the server assume that the proxy already terminated SSL, and
  #     that the request really is HTTPS, set `config.assume_ssl` to `true`:
  #
  #         config.assume_ssl = true
  #
  # 2.  **Secure cookies**: Sets the `secure` flag on cookies to tell browsers
  #     they must not be sent along with `http://` requests. Enabled by default.
  #     Set `config.ssl_options` with `secure_cookies: false` to disable this
  #     feature.
  #
  # 3.  **HTTP Strict Transport Security (HSTS)**: Tells the browser to remember
  #     this site as TLS-only and automatically redirect non-TLS requests. Enabled
  #     by default. Configure `config.ssl_options` with `hsts: false` to disable.
  #
  #     Set `config.ssl_options` with `hsts: { ... }` to configure HSTS:
  #
  #     *   `expires`: How long, in seconds, these settings will stick. The
  #         minimum required to qualify for browser preload lists is 1 year.
  #         Defaults to 2 years (recommended).
  #
  #     *   `subdomains`: Set to `true` to tell the browser to apply these
  #         settings to all subdomains. This protects your cookies from
  #         interception by a vulnerable site on a subdomain. Defaults to `true`.
  #
  #     *   `preload`: Advertise that this site may be included in browsers'
  #         preloaded HSTS lists. HSTS protects your site on every visit *except
  #         the first visit* since it hasn't seen your HSTS header yet. To close
  #         this gap, browser vendors include a baked-in list of HSTS-enabled
  #         sites. Go to https://hstspreload.org to submit your site for
  #         inclusion. Defaults to `false`.
  #
  #
  #     To turn off HSTS, omitting the header is not enough. Browsers will
  #     remember the original HSTS directive until it expires. Instead, use the
  #     header to tell browsers to expire HSTS immediately. Setting `hsts: false`
  #     is a shortcut for `hsts: { expires: 0 }`.
  #
  class SSL
    # :stopdoc: Default to 2 years as recommended on hstspreload.org.
    HSTS_EXPIRES_IN = 63072000

    PERMANENT_REDIRECT_REQUEST_METHODS = %w[GET HEAD] # :nodoc:

    def self.default_hsts_options
      { expires: HSTS_EXPIRES_IN, subdomains: true, preload: false }
    end

    def initialize(app, redirect: {}, hsts: {}, secure_cookies: true, ssl_default_redirect_status: nil)
      @app = app

      @redirect = redirect

      @exclude = @redirect && @redirect[:exclude] || proc { !@redirect }
      @secure_cookies = secure_cookies

      @hsts_header = build_hsts_header(normalize_hsts_options(hsts))
      @ssl_default_redirect_status = ssl_default_redirect_status
    end

    def call(env)
      request = Request.new env

      if request.ssl?
        @app.call(env).tap do |status, headers, body|
          set_hsts_header! headers
          flag_cookies_as_secure! headers if @secure_cookies && !@exclude.call(request)
        end
      else
        return redirect_to_https request unless @exclude.call(request)
        @app.call(env)
      end
    end

    private
      def set_hsts_header!(headers)
        headers[Constants::STRICT_TRANSPORT_SECURITY] ||= @hsts_header
      end

      def normalize_hsts_options(options)
        case options
        # Explicitly disabling HSTS clears the existing setting from browsers by setting
        # expiry to 0.
        when false
          self.class.default_hsts_options.merge(expires: 0)
        # Default to enabled, with default options.
        when nil, true
          self.class.default_hsts_options
        else
          self.class.default_hsts_options.merge(options)
        end
      end

      # https://tools.ietf.org/html/rfc6797#section-6.1
      def build_hsts_header(hsts)
        value = +"max-age=#{hsts[:expires].to_i}"
        value << "; includeSubDomains" if hsts[:subdomains]
        value << "; preload" if hsts[:preload]
        value
      end

      def flag_cookies_as_secure!(headers)
        cookies = headers[Rack::SET_COOKIE]
        return unless cookies

        if Gem::Version.new(Rack::RELEASE) < Gem::Version.new("3")
          cookies = cookies.split("\n")
          headers[Rack::SET_COOKIE] = cookies.map { |cookie|
            if !/;\s*secure\s*(;|$)/i.match?(cookie)
              "#{cookie}; secure"
            else
              cookie
            end
          }.join("\n")
        else
          headers[Rack::SET_COOKIE] = Array(cookies).map do |cookie|
            if !/;\s*secure\s*(;|$)/i.match?(cookie)
              "#{cookie}; secure"
            else
              cookie
            end
          end
        end
      end

      def redirect_to_https(request)
        [ @redirect.fetch(:status, redirection_status(request)),
          { Rack::CONTENT_TYPE => "text/html; charset=utf-8",
            Constants::LOCATION => https_location_for(request) },
          (@redirect[:body] || []) ]
      end

      def redirection_status(request)
        if PERMANENT_REDIRECT_REQUEST_METHODS.include?(request.raw_request_method)
          301 # Issue a permanent redirect via a GET request.
        elsif @ssl_default_redirect_status
          @ssl_default_redirect_status
        else
          307 # Issue a fresh request redirect to preserve the HTTP method.
        end
      end

      def https_location_for(request)
        host = @redirect[:host] || request.host
        port = @redirect[:port] || request.port

        location = +"https://#{host}"
        location << ":#{port}" if port != 80 && port != 443
        location << request.fullpath
        location
      end
  end
end
