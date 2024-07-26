module ActionController
  class AbstractRequest #:nodoc:
    # Returns both GET and POST parameters in a single hash.
    def parameters
      @parameters ||= request_parameters.update(query_parameters)
    end

    def request_uri
      env["REQUEST_URI"]
    end

    def protocol
      port == 443 ? "https://" : "http://"
    end

    def path
      request_uri.split("?").first
    end

    def port
      env["SERVER_PORT"].to_i
    end

    # Must be implemented in the concrete request
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