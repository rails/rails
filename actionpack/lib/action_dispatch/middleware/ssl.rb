module ActionDispatch
  # This middleware is added to the stack when `config.force_ssl = true`, and is passed
  # the options set in `config.ssl_options`. It does three jobs to enforce secure HTTP
  # requests:
  #
  #   1. TLS redirect: Permanently redirects http:// requests to https://
  #      with the same URL host, path, etc. Enabled by default. Set `config.ssl_options`
  #      to modify the destination URL
  #      (e.g. `redirect: { host: "secure.widgets.com", port: 8080 }`), or set
  #      `redirect: false` to disable this feature.
  #
  #   2. Secure cookies: Sets the `secure` flag on cookies to tell browsers they
  #      mustn't be sent along with http:// requests. Enabled by default. Set
  #      `config.ssl_options` with `secure_cookies: false` to disable this feature.
  #
  #   3. HTTP Strict Transport Security (HSTS): Tells the browser to remember
  #      this site as TLS-only and automatically redirect non-TLS requests.
  #      Enabled by default. Configure `config.ssl_options` with `hsts: false` to disable.
  #
  # Set `config.ssl_options` with `hsts: { … }` to configure HSTS:
  #   * `expires`: How long, in seconds, these settings will stick. The minimum
  #     required to qualify for browser preload lists is `18.weeks`. Defaults to
  #     `180.days` (recommended).
  #   * `subdomains`: Set to `true` to tell the browser to apply these settings
  #     to all subdomains. This protects your cookies from interception by a
  #     vulnerable site on a subdomain. Defaults to `false`.
  #   * `preload`: Advertise that this site may be included in browsers'
  #     preloaded HSTS lists. HSTS protects your site on every visit *except the
  #     first visit* since it hasn't seen your HSTS header yet. To close this
  #     gap, browser vendors include a baked-in list of HSTS-enabled sites.
  #     Go to https://hstspreload.appspot.com to submit your site for inclusion.
  #     Defaults to `false`.
  #
  # To turn off HSTS, omitting the header is not enough. Browsers will remember the
  # original HSTS directive until it expires. Instead, use the header to tell browsers to
  # expire HSTS immediately. Setting `hsts: false` is a shortcut for
  # `hsts: { expires: 0 }`.
  #
  # Requests can opt-out of redirection with `exclude`:
  #
  #    config.ssl_options = { redirect: { exclude: -> request { request.path =~ /healthcheck/ } } }
  class SSL
    # Default to 180 days, the low end for https://www.ssllabs.com/ssltest/
    # and greater than the 18-week requirement for browser preload lists.
    HSTS_EXPIRES_IN = 15552000

    def self.default_hsts_options
      { expires: HSTS_EXPIRES_IN, subdomains: false, preload: false }
    end

    def initialize(app, redirect: {}, hsts: {}, secure_cookies: true, **options)
      @app = app

      if options[:host] || options[:port]
        ActiveSupport::Deprecation.warn <<-end_warning.strip_heredoc
          The `:host` and `:port` options are moving within `:redirect`:
          `config.ssl_options = { redirect: { host: …, port: … } }`.
        end_warning
        @redirect = options.slice(:host, :port)
      else
        @redirect = redirect
      end

      @exclude = @redirect && @redirect[:exclude] || proc { !@redirect }
      @secure_cookies = secure_cookies

      if hsts != true && hsts != false && hsts[:subdomains].nil?
        hsts[:subdomains] = false

        ActiveSupport::Deprecation.warn <<-end_warning.strip_heredoc
          In Rails 5.1, The `:subdomains` option of HSTS config will be treated as true if
          unspecified. Set `config.ssl_options = { hsts: { subdomains: false } }` to opt out
          of this behavior.
        end_warning
      end

      @hsts_header = build_hsts_header(normalize_hsts_options(hsts))
    end

    def call(env)
      request = Request.new env

      if request.ssl?
        @app.call(env).tap do |status, headers, body|
          set_hsts_header! headers
          flag_cookies_as_secure! headers if @secure_cookies
        end
      else
        return redirect_to_https request unless @exclude.call(request)
        @app.call(env)
      end
    end

    private
      def set_hsts_header!(headers)
        headers['Strict-Transport-Security'.freeze] ||= @hsts_header
      end

      def normalize_hsts_options(options)
        case options
        # Explicitly disabling HSTS clears the existing setting from browsers
        # by setting expiry to 0.
        when false
          self.class.default_hsts_options.merge(expires: 0)
        # Default to enabled, with default options.
        when nil, true
          self.class.default_hsts_options
        else
          self.class.default_hsts_options.merge(options)
        end
      end

      # http://tools.ietf.org/html/rfc6797#section-6.1
      def build_hsts_header(hsts)
        value = "max-age=#{hsts[:expires].to_i}"
        value << "; includeSubDomains" if hsts[:subdomains]
        value << "; preload" if hsts[:preload]
        value
      end

      def flag_cookies_as_secure!(headers)
        if cookies = headers['Set-Cookie'.freeze]
          cookies = cookies.split("\n".freeze)

          headers['Set-Cookie'.freeze] = cookies.map { |cookie|
            if cookie !~ /;\s*secure\s*(;|$)/i
              "#{cookie}; secure"
            else
              cookie
            end
          }.join("\n".freeze)
        end
      end

      def redirect_to_https(request)
        [ @redirect.fetch(:status, 301),
          { 'Content-Type' => 'text/html',
            'Location' => https_location_for(request) },
          @redirect.fetch(:body, []) ]
      end

      def https_location_for(request)
        host = @redirect[:host] || request.host
        port = @redirect[:port] || request.port

        location = "https://#{host}"
        location << ":#{port}" if port != 80 && port != 443
        location << request.fullpath
        location
      end
  end
end
