# frozen_string_literal: true

module ActionDispatch
  # This middleware is added to the stack when <tt>config.force_ssl = true</tt>, and is passed
  # the options set in +config.ssl_options+. It does three jobs to enforce secure HTTP
  # requests:
  #
  # 1. <b>TLS redirect</b>: Permanently redirects +http://+ requests to +https://+
  #    with the same URL host, path, etc. Enabled by default. Set +config.ssl_options+
  #    to modify the destination URL
  #    (e.g. <tt>redirect: { host: "secure.widgets.com", port: 8080 }</tt>), or set
  #    <tt>redirect: false</tt> to disable this feature.
  #
  #    Requests can opt-out of redirection with +exclude+:
  #
  #      config.ssl_options = { redirect: { exclude: -> request { request.path =~ /healthcheck/ } } }
  #
  #    Cookies will not be flagged as secure for excluded requests.
  #
  # 2. <b>Secure cookies</b>: Sets the +secure+ flag on cookies to tell browsers they
  #    must not be sent along with +http://+ requests. Enabled by default. Set
  #    +config.ssl_options+ with <tt>secure_cookies: false</tt> to disable this feature.
  #
  # 3. <b>HTTP Strict Transport Security (HSTS)</b>: Tells the browser to remember
  #    this site as TLS-only and automatically redirect non-TLS requests.
  #    Enabled by default. Configure +config.ssl_options+ with <tt>hsts: false</tt> to disable.
  #
  #    Set +config.ssl_options+ with <tt>hsts: { ... }</tt> to configure HSTS:
  #
  #    * +expires+: How long, in seconds, these settings will stick. The minimum
  #      required to qualify for browser preload lists is 1 year. Defaults to
  #      1 year (recommended).
  #
  #    * +subdomains+: Set to +true+ to tell the browser to apply these settings
  #      to all subdomains. This protects your cookies from interception by a
  #      vulnerable site on a subdomain. Defaults to +true+.
  #
  #    * +preload+: Advertise that this site may be included in browsers'
  #      preloaded HSTS lists. HSTS protects your site on every visit <i>except the
  #      first visit</i> since it hasn't seen your HSTS header yet. To close this
  #      gap, browser vendors include a baked-in list of HSTS-enabled sites.
  #      Go to https://hstspreload.org to submit your site for inclusion.
  #      Defaults to +false+.
  #
  #    To turn off HSTS, omitting the header is not enough. Browsers will remember the
  #    original HSTS directive until it expires. Instead, use the header to tell browsers to
  #    expire HSTS immediately. Setting <tt>hsts: false</tt> is a shortcut for
  #    <tt>hsts: { expires: 0 }</tt>.
  class SSL
    # :stopdoc:

    # Default to 1 year, the minimum for browser preload lists.
    HSTS_EXPIRES_IN = 31536000

    def self.default_hsts_options
      { expires: HSTS_EXPIRES_IN, subdomains: true, preload: false }
    end

    def initialize(app, redirect: {}, hsts: {}, secure_cookies: true)
      @app = app

      @redirect = redirect

      @exclude = @redirect && @redirect[:exclude] || proc { !@redirect }
      @secure_cookies = secure_cookies

      @hsts_header = build_hsts_header(normalize_hsts_options(hsts))
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
        headers["Strict-Transport-Security".freeze] ||= @hsts_header
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

      # https://tools.ietf.org/html/rfc6797#section-6.1
      def build_hsts_header(hsts)
        value = "max-age=#{hsts[:expires].to_i}".dup
        value << "; includeSubDomains" if hsts[:subdomains]
        value << "; preload" if hsts[:preload]
        value
      end

      def flag_cookies_as_secure!(headers)
        if cookies = headers["Set-Cookie".freeze]
          cookies = cookies.split("\n".freeze)

          headers["Set-Cookie".freeze] = cookies.map { |cookie|
            if !/;\s*secure\s*(;|$)/i.match?(cookie)
              "#{cookie}; secure"
            else
              cookie
            end
          }.join("\n".freeze)
        end
      end

      def redirect_to_https(request)
        [ @redirect.fetch(:status, redirection_status(request)),
          { "Content-Type" => "text/html",
            "Location" => https_location_for(request) },
          @redirect.fetch(:body, []) ]
      end

      def redirection_status(request)
        if request.get? || request.head?
          301 # Issue a permanent redirect via a GET request.
        else
          307 # Issue a fresh request redirect to preserve the HTTP method.
        end
      end

      def https_location_for(request)
        host = @redirect[:host] || request.host
        port = @redirect[:port] || request.port

        location = "https://#{host}".dup
        location << ":#{port}" if port != 80 && port != 443
        location << request.fullpath
        location
      end
  end
end
