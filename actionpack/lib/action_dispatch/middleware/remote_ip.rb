module ActionDispatch
  # This middleware calculates the IP address of the remote client that is
  # making the request. It does this by checking various headers that could
  # contain the address, and then picking the last-set address that is not
  # on the list of trusted IPs. This follows the precedent set by e.g.
  # {the Tomcat server}[https://issues.apache.org/bugzilla/show_bug.cgi?id=50453],
  # with {reasoning explained at length}[http://blog.gingerlime.com/2012/rails-ip-spoofing-vulnerabilities-and-protection]
  # by @gingerlime. A more detailed explanation of the algorithm is given
  # at GetIp#calculate_ip.
  #
  # Some Rack servers concatenate repeated headers, like {HTTP RFC 2616}[http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2]
  # requires. Some Rack servers simply drop preceeding headers, and only report
  # the value that was {given in the last header}[http://andre.arko.net/2011/12/26/repeated-headers-and-ruby-web-servers].
  # If you are behind multiple proxy servers (like Nginx to HAProxy to Unicorn)
  # then you should test your Rack server to make sure your data is good.
  #
  # IF YOU DON'T USE A PROXY, THIS MAKES YOU VULNERABLE TO IP SPOOFING.
  # This middleware assumes that there is at least one proxy sitting around
  # and setting headers with the client's remote IP address. If you don't use
  # a proxy, because you are hosted on e.g. Heroku without SSL, any client can
  # claim to have any IP address by setting the X-Forwarded-For header. If you
  # care about that, then you need to explicitly drop or ignore those headers
  # sometime before this middleware runs.
  class RemoteIp
    class IpSpoofAttackError < StandardError; end

    # The default trusted IPs list simply includes IP addresses that are
    # guaranteed by the IP specification to be private addresses. Those will
    # not be the ultimate client IP in production, and so are discarded. See
    # http://en.wikipedia.org/wiki/Private_network for details.
    TRUSTED_PROXIES = %r{
      ^127\.0\.0\.1$                | # localhost IPv4
      ^::1$                         | # localhost IPv6
      ^fc00:                        | # private IPv6 range fc00
      ^10\.                         | # private IPv4 range 10.x.x.x
      ^172\.(1[6-9]|2[0-9]|3[0-1])\.| # private IPv4 range 172.16.0.0 .. 172.31.255.255
      ^192\.168\.                     # private IPv4 range 192.168.x.x
    }x

    attr_reader :check_ip, :proxies

    # Create a new +RemoteIp+ middleware instance.
    #
    # The +check_ip_spoofing+ option is on by default. When on, an exception
    # is raised if it looks like the client is trying to lie about its own IP
    # address. It makes sense to turn off this check on sites aimed at non-IP
    # clients (like WAP devices), or behind proxies that set headers in an
    # incorrect or confusing way (like AWS ELB).
    #
    # The +custom_trusted+ argument can take a regex, which will be used
    # instead of +TRUSTED_PROXIES+, or a string, which will be used in addition
    # to +TRUSTED_PROXIES+. Any proxy setup will put the value you want in the
    # middle (or at the beginning) of the X-Forwarded-For list, with your proxy
    # servers after it. If your proxies aren't removed, pass them in via the
    # +custom_trusted+ parameter. That way, the middleware will ignore those
    # IP addresses, and return the one that you want.
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

    # Since the IP address may not be needed, we store the object here
    # without calculating the IP to keep from slowing down the majority of
    # requests. For those requests that do need to know the IP, the
    # GetIp#calculate_ip method will calculate the memoized client IP address.
    def call(env)
      env["action_dispatch.remote_ip"] = GetIp.new(env, self)
      @app.call(env)
    end

    # The GetIp class exists as a way to defer processing of the request data
    # into an actual IP address. If the ActionDispatch::Request#remote_ip method
    # is called, this class will calculate the value and then memoize it.
    class GetIp

      # This constant contains a regular expression that validates every known
      # form of IP v4 and v6 address, with or without abbreviations, adapted
      # from {this gist}[https://gist.github.com/1289635].
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
        @env      = env
        @check_ip = middleware.check_ip
        @proxies  = middleware.proxies
      end

      # Sort through the various IP address headers, looking for the IP most
      # likely to be the address of the actual remote client making this
      # request.
      #
      # REMOTE_ADDR will be correct if the request is made directly against the
      # Ruby process, on e.g. Heroku. When the request is proxied by another
      # server like HAProxy or Nginx, the IP address that made the original
      # request will be put in an X-Forwarded-For header. If there are multiple
      # proxies, that header may contain a list of IPs. Other proxy services
      # set the Client-Ip header instead, so we check that too.
      #
      # As discussed in {this post about Rails IP Spoofing}[http://blog.gingerlime.com/2012/rails-ip-spoofing-vulnerabilities-and-protection/],
      # while the first IP in the list is likely to be the "originating" IP,
      # it could also have been set by the client maliciously.
      #
      # In order to find the first address that is (probably) accurate, we
      # take the list of IPs, remove known and trusted proxies, and then take
      # the last address left, which was presumably set by one of those proxies.
      def calculate_ip
        # Set by the Rack web server, this is a single value.
        remote_addr = ips_from('REMOTE_ADDR').last

        # Could be a CSV list and/or repeated headers that were concatenated.
        client_ips    = ips_from('HTTP_CLIENT_IP').reverse
        forwarded_ips = ips_from('HTTP_X_FORWARDED_FOR').reverse

        # +Client-Ip+ and +X-Forwarded-For+ should not, generally, both be set.
        # If they are both set, it means that this request passed through two
        # proxies with incompatible IP header conventions, and there is no way
        # for us to determine which header is the right one after the fact.
        # Since we have no idea, we give up and explode.
        should_check_ip = @check_ip && client_ips.last
        if should_check_ip && !forwarded_ips.include?(client_ips.last)
          # We don't know which came from the proxy, and which from the user
          raise IpSpoofAttackError, "IP spoofing attack?! " +
            "HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect} " +
            "HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}"
        end

        # We assume these things about the IP headers:
        #
        #   - X-Forwarded-For will be a list of IPs, one per proxy, or blank
        #   - Client-Ip is propagated from the outermost proxy, or is blank
        #   - REMOTE_ADDR will be the IP that made the request to Rack
        ips = [forwarded_ips, client_ips, remote_addr].flatten.compact

        # If every single IP option is in the trusted list, just return REMOTE_ADDR
        filter_proxies(ips).first || remote_addr
      end

      # Memoizes the value returned by #calculate_ip and returns it for
      # ActionDispatch::Request to use.
      def to_s
        @ip ||= calculate_ip
      end

    protected

      def ips_from(header)
        # Split the comma-separated list into an array of strings
        ips = @env[header] ? @env[header].strip.split(/[,\s]+/) : []
        # Only return IPs that are valid according to the regex
        ips.select{ |ip| ip =~ VALID_IP }
      end

      def filter_proxies(ips)
        ips.reject { |ip| ip =~ @proxies }
      end

    end

  end
end
