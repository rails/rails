module ActionDispatch
  class RemoteIp
    class IpSpoofAttackError < StandardError ; end

    # IP addresses that are "trusted proxies" that can be stripped from
    # the comma-delimited list in the X-Forwarded-For header. See also:
    # http://en.wikipedia.org/wiki/Private_network#Private_IPv4_address_spaces
    # http://en.wikipedia.org/wiki/Private_network#Private_IPv6_addresses.
    TRUSTED_PROXIES = %r{
      ^127\.0\.0\.1$                | # localhost
      ^::1$                         |
      ^(10                          | # private IP 10.x.x.x
        172\.(1[6-9]|2[0-9]|3[0-1]) | # private IP in the range 172.16.0.0 .. 172.31.255.255
        192\.168                    | # private IP 192.168.x.x
        fc00::                        # private IP fc00
       )\.
    }x

    attr_reader :check_ip, :proxies

    def initialize(app, check_ip_spoofing = true, custom_proxies = nil)
      @app = app
      @check_ip = check_ip_spoofing
      @proxies = case custom_proxies
        when Regexp
          custom_proxies
        when nil
          TRUSTED_PROXIES
        else
          Regexp.union(TRUSTED_PROXIES, custom_proxies)
        end
    end

    def call(env)
      env["action_dispatch.remote_ip"] = GetIp.new(env, self)
      @app.call(env)
    end

    class GetIp

      # IP v4 and v6 (with compression) validation regexp
      # https://gist.github.com/1289635
      VALID_IP = %r{
        (^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[0-9]{1,2})){3}$)                                                        | # ip v4
        (^(
        (([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4})                                                                                                                   | # ip v6 not abbreviated
        (([0-9A-Fa-f]{1,4}:){6}:[0-9A-Fa-f]{1,4})                                                                                                                  | # ip v6 with double colon in the end
        (([0-9A-Fa-f]{1,4}:){5}:([0-9A-Fa-f]{1,4}:)?[0-9A-Fa-f]{1,4})                                                                                              | # - ip addresses v6
        (([0-9A-Fa-f]{1,4}:){4}:([0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})                                                                                          | # - with
        (([0-9A-Fa-f]{1,4}:){3}:([0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})                                                                                          | # - double colon
        (([0-9A-Fa-f]{1,4}:){2}:([0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})                                                                                          | # - in the middle
        (([0-9A-Fa-f]{1,4}:){6} ((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3} (\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))                            | # ip v6 with compatible to v4
        (([0-9A-Fa-f]{1,4}:){1,5}:((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))                           | # ip v6 with compatible to v4
        (([0-9A-Fa-f]{1,4}:){1}:([0-9A-Fa-f]{1,4}:){0,4}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))     | # ip v6 with compatible to v4
        (([0-9A-Fa-f]{1,4}:){0,2}:([0-9A-Fa-f]{1,4}:){0,3}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))   | # ip v6 with compatible to v4
        (([0-9A-Fa-f]{1,4}:){0,3}:([0-9A-Fa-f]{1,4}:){0,2}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))   | # ip v6 with compatible to v4
        (([0-9A-Fa-f]{1,4}:){0,4}:([0-9A-Fa-f]{1,4}:){1}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))     | # ip v6 with compatible to v4
        (::([0-9A-Fa-f]{1,4}:){0,5}((\b((25[0-5])|(1\d{2})|(2[0-4]\d) |(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))                         | # ip v6 with compatible to v4
        ([0-9A-Fa-f]{1,4}::([0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})                                                                                               | # ip v6 with compatible to v4
        (::([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})                                                                                                               | # ip v6 with double colon at the begining
        (([0-9A-Fa-f]{1,4}:){1,7}:)                                                                                                                                  # ip v6 without ending
        )$)
      }x

      def initialize(env, middleware)
        @env        = env
        @middleware = middleware
        @ip         = nil
      end

      # Determines originating IP address. REMOTE_ADDR is the standard
      # but will be wrong if the user is behind a proxy. Proxies will set
      # HTTP_CLIENT_IP and/or HTTP_X_FORWARDED_FOR, so we prioritize those.
      # HTTP_X_FORWARDED_FOR may be a comma-delimited list in the case of
      # multiple chained proxies. The first address which is in this list
      # if it's not a known proxy will be the originating IP.
      # Format of HTTP_X_FORWARDED_FOR:
      # client_ip, proxy_ip1, proxy_ip2...
      # http://en.wikipedia.org/wiki/X-Forwarded-For
      def calculate_ip
        client_ip    = @env['HTTP_CLIENT_IP']
        forwarded_ip = ips_from('HTTP_X_FORWARDED_FOR').first
        remote_addrs = ips_from('REMOTE_ADDR')

        check_ip = client_ip && @middleware.check_ip
        if check_ip && forwarded_ip != client_ip
          # We don't know which came from the proxy, and which from the user
          raise IpSpoofAttackError, "IP spoofing attack?!" \
            "HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect}" \
            "HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}"
        end

        client_ips = remove_proxies [client_ip, forwarded_ip, remote_addrs].flatten
        if client_ips.present?
          client_ips.first
        else
          # If there is no client ip we can return first valid proxy ip from REMOTE_ADDR
          remote_addrs.find { |ip| valid_ip? ip }
        end
      end

      def to_s
        @ip ||= calculate_ip
      end

      private

      def ips_from(header)
        @env[header] ? @env[header].strip.split(/[,\s]+/) : []
      end

      def valid_ip?(ip)
        ip =~ VALID_IP
      end

      def not_a_proxy?(ip)
        ip !~ @middleware.proxies
      end

      def remove_proxies(ips)
        ips.select { |ip| valid_ip?(ip) && not_a_proxy?(ip) }
      end

    end

  end
end
