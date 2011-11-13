module ActionDispatch
  class RemoteIp
    class IpSpoofAttackError < StandardError ; end

    # IP addresses that are "trusted proxies" that can be stripped from
    # the comma-delimited list in the X-Forwarded-For header. See also:
    # http://en.wikipedia.org/wiki/Private_network#Private_IPv4_address_spaces
    TRUSTED_PROXIES = %r{
      ^127\.0\.0\.1$                | # localhost
      ^(10                          | # private IP 10.x.x.x
        172\.(1[6-9]|2[0-9]|3[0-1]) | # private IP in the range 172.16.0.0 .. 172.31.255.255
        192\.168                      # private IP 192.168.x.x
       )\.
    }x

    attr_reader :check_ip_spoofing, :trusted_proxies

    def initialize(app, check_ip_spoofing = true, custom_proxies = nil)
      @app = app
      @check_ip_spoofing = check_ip_spoofing
      if custom_proxies
        custom_regexp = Regexp.new(custom_proxies)
        @trusted_proxies = Regexp.union(TRUSTED_PROXIES, custom_regexp)
      else
        @trusted_proxies = TRUSTED_PROXIES
      end
    end

    def call(env)
      env["action_dispatch.remote_ip"] = GetIp.new(env, self)
      @app.call(env)
    end

    class GetIp
      def initialize(env, middleware)
        @env, @middleware = env, middleware
      end

      # Determines originating IP address. REMOTE_ADDR is the standard
      # but will be wrong if the user is behind a proxy. Proxies will set
      # HTTP_CLIENT_IP and/or HTTP_X_FORWARDED_FOR, so we prioritize those.
      # HTTP_X_FORWARDED_FOR may be a comma-delimited list in the case of
      # multiple chained proxies. The last address which is not a known proxy
      # will be the originating IP.
      def to_s
        client_ip     = @env['HTTP_CLIENT_IP']
        forwarded_ips = ips_from('HTTP_X_FORWARDED_FOR')
        remote_addrs  = ips_from('REMOTE_ADDR')

        check_ip = client_ip && @middleware.check_ip_spoofing
        if check_ip && !forwarded_ips.include?(client_ip)
          # We don't know which came from the proxy, and which from the user
          raise IpSpoofAttackError, "IP spoofing attack?!" \
            "HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect}" \
            "HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}"
        end

        client_ip || forwarded_ips.last || remote_addrs.first
      end

    protected

      def ips_from(header)
        ips = @env[header] ? @env[header].strip.split(/[,\s]+/) : []
        ips.reject{|ip| ip =~ @middleware.trusted_proxies }
      end
    end

  end
end
