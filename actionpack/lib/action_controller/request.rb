module ActionController
  # These methods are available in both the production and test Request objects.
  class AbstractRequest
    # Returns both GET and POST parameters in a single hash.
    def parameters
      @parameters ||= request_parameters.update(query_parameters)
    end

    def method
      env['REQUEST_METHOD'].downcase.intern
    end

    def get?
      method == :get
    end

    def post?
      method == :post
    end

    def put?
      method == :put
    end

    def delete?
      method == :delete
    end

    def head?
      method == :head
    end
    
    
    # Determine originating IP address.  REMOTE_ADDR is the standard
    # but will fail if the user is behind a proxy.  HTTP_CLIENT_IP and/or
    # HTTP_X_FORWARDED_FOR are set by proxies so check for these before
    # falling back to REMOTE_ADDR.  HTTP_X_FORWARDED_FOR may be a comma-
    # delimited list in the case of multiple chained proxies; the first is
    # the originating IP.
    def remote_ip
      return env['HTTP_CLIENT_IP'] if env.include? 'HTTP_CLIENT_IP'

      if env.include? 'HTTP_X_FORWARDED_FOR' then
        remote_ips = env['HTTP_X_FORWARDED_FOR'].split(',').reject do |ip|
            ip =~ /^unknown$|^(10|172\.16|192\.168)\./i
        end

        return remote_ips.first.strip unless remote_ips.empty?
      end

      return env['REMOTE_ADDR']
    end

    # Returns the domain part of a host, such as rubyonrails.org in "www.rubyonrails.org". You can specify
    # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
    def domain(tld_length = 1)
      host.split('.').last(1 + tld_length).join('.')
    end

    # Returns all the subdomains as an array, so ["dev", "www"] would be returned for "dev.www.rubyonrails.org".
    # You can specify a different <tt>tld_length</tt>, such as 2 to catch ["www"] instead of ["www", "rubyonrails"]
    # in "www.rubyonrails.co.uk".
    def subdomains(tld_length = 1)
      parts = host.split('.')
      parts - parts.last(1 + tld_length)
    end

    # Recieve the raw post data. 
    # This is useful for services such as REST, XMLRPC and SOAP 
    # which communicate over HTTP POST but don't use the traditional parameter format. 
    def raw_post
      env['RAW_POST_DATA']
    end
    
    def request_uri
      env['REQUEST_URI']
    end

    def protocol
      port == 443 ? 'https://' : 'http://'
    end

    def ssl?
      protocol == 'https://'
    end

    def path
      request_uri ? request_uri.split('?').first : ''
    end

    def port
      env['SERVER_PORT'].to_i
    end

    # Returns a string like ":8080" if the port is not 80 or 443 while on https.
    def port_string
      (protocol == 'http://' && port == 80) || (protocol == 'https://' && port == 443) ? '' : ":#{port}"
    end

    def host_with_port
      env['HTTP_HOST'] || host + port_string
    end

    #--
    # Must be implemented in the concrete request
    #++
    def query_parameters
    end

    def request_parameters
    end

    def env
    end

    def host
    end

    def cookies
    end

    def session
    end

    def reset_session
    end    
  end
end
