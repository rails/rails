require 'ipaddr'

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
  # requires. Some Rack servers simply drop preceding headers, and only report
  # the value that was {given in the last header}[http://andre.arko.net/2011/12/26/repeated-headers-and-ruby-web-servers].
  # If you are behind multiple proxy servers (like NGINX to HAProxy to Unicorn)
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
    TRUSTED_PROXIES = [
      "127.0.0.1",      # localhost IPv4
      "::1",            # localhost IPv6
      "fc00::/7",       # private IPv6 range fc00::/7
      "10.0.0.0/8",     # private IPv4 range 10.x.x.x
      "172.16.0.0/12",  # private IPv4 range 172.16.0.0 .. 172.31.255.255
      "192.168.0.0/16", # private IPv4 range 192.168.x.x
    ].map { |proxy| IPAddr.new(proxy) }

    attr_reader :check_ip, :proxies

    # Create a new +RemoteIp+ middleware instance.
    #
    # The +ip_spoofing_check+ option is on by default. When on, an exception
    # is raised if it looks like the client is trying to lie about its own IP
    # address. It makes sense to turn off this check on sites aimed at non-IP
    # clients (like WAP devices), or behind proxies that set headers in an
    # incorrect or confusing way (like AWS ELB).
    #
    # The +custom_proxies+ argument can take an Array of string, IPAddr, or
    # Regexp objects which will be used instead of +TRUSTED_PROXIES+. If a
    # single string, IPAddr, or Regexp object is provided, it will be used in
    # addition to +TRUSTED_PROXIES+. Any proxy setup will put the value you
    # want in the middle (or at the beginning) of the X-Forwarded-For list,
    # with your proxy servers after it. If your proxies aren't removed, pass
    # them in via the +custom_proxies+ parameter. That way, the middleware will
    # ignore those IP addresses, and return the one that you want.
    def initialize(app, ip_spoofing_check = true, custom_proxies = nil)
      @app = app
      @check_ip = ip_spoofing_check
      @proxies = if custom_proxies.blank?
        TRUSTED_PROXIES
      elsif custom_proxies.respond_to?(:any?)
        custom_proxies
      else
        Array(custom_proxies) + TRUSTED_PROXIES
      end
    end

    # Since the IP address may not be needed, we store the object here
    # without calculating the IP to keep from slowing down the majority of
    # requests. For those requests that do need to know the IP, the
    # GetIp#calculate_ip method will calculate the memoized client IP address.
    def call(env)
      req = ActionDispatch::Request.new env
      req.remote_ip = GetIp.new(req, check_ip, proxies)
      @app.call(req.env)
    end

    # The GetIp class exists as a way to defer processing of the request data
    # into an actual IP address. If the ActionDispatch::Request#remote_ip method
    # is called, this class will calculate the value and then memoize it.
    class GetIp
      def initialize(req, check_ip, proxies)
        @req      = req
        @check_ip = check_ip
        @proxies  = proxies
      end

      # Sort through the various IP address headers, looking for the IP most
      # likely to be the address of the actual remote client making this
      # request.
      #
      # REMOTE_ADDR will be correct if the request is made directly against the
      # Ruby process, on e.g. Heroku. When the request is proxied by another
      # server like HAProxy or NGINX, the IP address that made the original
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
        remote_addr = ips_from(@req.remote_addr).last

        # Could be a CSV list and/or repeated headers that were concatenated.
        client_ips    = ips_from(@req.client_ip).reverse
        forwarded_ips = ips_from(@req.x_forwarded_for).reverse

        # +Client-Ip+ and +X-Forwarded-For+ should not, generally, both be set.
        # If they are both set, it means that either:
        #
        # 1) This request passed through two proxies with incompatible IP header
        #    conventions.
        # 2) The client passed one of +Client-Ip+ or +X-Forwarded-For+
        #    (whichever the proxy servers weren't using) themselves.
        #
        # Either way, there is no way for us to determine which header is the
        # right one after the fact. Since we have no idea, if we are concerned
        # about IP spoofing we need to give up and explode. (If you're not
        # concerned about IP spoofing you can turn the +ip_spoofing_check+
        # option off.)
        should_check_ip = @check_ip && client_ips.last && forwarded_ips.last
        if should_check_ip && !forwarded_ips.include?(client_ips.last)
          # We don't know which came from the proxy, and which from the user
          raise IpSpoofAttackError, "IP spoofing attack?! " +
            "HTTP_CLIENT_IP=#{@req.client_ip.inspect} " +
            "HTTP_X_FORWARDED_FOR=#{@req.x_forwarded_for.inspect}"
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
        return [] unless header
        # Split the comma-separated list into an array of strings
        ips = header.strip.split(/[,\s]+/)
        ips.select do |ip|
          begin
            # Only return IPs that are valid according to the IPAddr#new method
            range = IPAddr.new(ip).to_range
            # we want to make sure nobody is sneaking a netmask in
            range.begin == range.end
          rescue ArgumentError
            nil
          end
        end
      end

      def filter_proxies(ips)
        ips.reject do |ip|
          @proxies.any? { |proxy| proxy === ip }
        end
      end

    end

  end
end
