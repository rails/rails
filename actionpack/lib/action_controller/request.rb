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

    # Determine originating IP address.  REMOTE_ADDR is the standard
    # but will fail if the user is behind a proxy.  HTTP_CLIENT_IP and/or
    # HTTP_X_FORWARDED_FOR are set by proxies so check for these before
    # falling back to REMOTE_ADDR.  HTTP_X_FORWARDED_FOR may be a comma-
    # delimited list in the case of multiple chained proxies; the first is
    # the originating IP.
    def remote_ip
      if env['HTTP_CLIENT_IP']
        env['HTTP_CLIENT_IP']
      elsif env['HTTP_X_FORWARDED_FOR']
        remote_ip = env['HTTP_X_FORWARDED_FOR'].split(',').reject { |ip|
            ip =~ /^unknown$|^(10|172\.16|192\.168)\./i
        }.first
        
        remote_ip ? remote_ip.strip : env['REMOTE_ADDR']
      else
        env['REMOTE_ADDR']
      end
    end

    def request_uri
      env["REQUEST_URI"]
    end

    def protocol
      port == 443 ? "https://" : "http://"
    end

    def path
      request_uri ? request_uri.split("?").first : ""
    end

    def port
      env["SERVER_PORT"].to_i
    end

    def host_with_port
      if env['HTTP_HOST']
        env['HTTP_HOST']
      elsif (protocol == "http://" && port == 80) || (protocol == "https://" && port == 443)
        host
      else
        host + ":#{port}"
      end
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
