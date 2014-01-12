module ActionDispatch
  class SSL
    YEAR = 31536000

    def self.default_hsts_options
      { :expires => YEAR, :subdomains => false }
    end

    def initialize(app, options = {})
      @app = app

      @hsts = options.fetch(:hsts, {})
      @hsts = {} if @hsts == true
      @hsts = self.class.default_hsts_options.merge(@hsts) if @hsts

      @host    = options[:host]
      @port    = options[:port]
    end

    def call(env)
      request = Request.new(env)

      if request.ssl?
        status, headers, body = @app.call(env)
        headers = hsts_headers.merge(headers)
        flag_cookies_as_secure!(headers)
        [status, headers, body]
      else
        redirect_to_https(request)
      end
    end

    private
      def redirect_to_https(request)
        url        = URI(request.url)
        url.scheme = "https"
        url.host   = @host if @host
        url.port   = @port if @port
        headers    = { 'Content-Type' => 'text/html', 'Location' => url.to_s }

        [301, headers, []]
      end

      # http://tools.ietf.org/html/draft-hodges-strict-transport-sec-02
      def hsts_headers
        if @hsts
          value = "max-age=#{@hsts[:expires].to_i}"
          value += "; includeSubDomains" if @hsts[:subdomains]
          { 'Strict-Transport-Security' => value }
        else
          {}
        end
      end

      def flag_cookies_as_secure!(headers)
        if cookies = headers['Set-Cookie']
          cookies = cookies.split("\n")

          headers['Set-Cookie'] = cookies.map { |cookie|
            if cookie !~ /;\s*secure\s*(;|$)/i
              "#{cookie}; secure"
            else
              cookie
            end
          }.join("\n")
        end
      end
  end
end
