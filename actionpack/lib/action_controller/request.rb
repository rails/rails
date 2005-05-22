module ActionController
  # These methods are available in both the production and test Request objects.
  class AbstractRequest
    cattr_accessor :relative_url_root
    
    # Returns both GET and POST parameters in a single hash.
    def parameters
      @parameters ||= request_parameters.merge(query_parameters).merge(path_parameters).with_indifferent_access
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


    def post_format
      if env['HTTP_X_POST_DATA_FORMAT']
        env['HTTP_X_POST_DATA_FORMAT'].downcase.intern
      else
        case env['CONTENT_TYPE']
          when 'application/xml', 'text/xml'
            :xml
          when 'application/x-yaml', 'text/x-yaml'
            :yaml
          else
            :url_encoded
        end
      end
    end

    def formatted_post?
      [ :xml, :yaml ].include?(post_format) && post?
    end

    def xml_post?
      post_format == :xml && post?
    end

    def yaml_post?
      post_format == :yaml && post?
    end


    # Returns true if the request's "X-Requested-With" header contains
    # "XMLHttpRequest". (The Prototype Javascript library sends this header with
    # every Ajax request.)
    def xml_http_request?
      env['HTTP_X_REQUESTED_WITH'] =~ /XMLHttpRequest/i
    end
    alias xhr? :xml_http_request?

    
    
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
            ip =~ /^unknown$|^(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\./i
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

    # Receive the raw post data. 
    # This is useful for services such as REST, XMLRPC and SOAP 
    # which communicate over HTTP POST but don't use the traditional parameter format. 
    def raw_post
      env['RAW_POST_DATA']
    end
    
    def request_uri
      unless env['REQUEST_URI'].nil?
        (%r{^\w+\://[^/]+(/.*|$)$} =~ env['REQUEST_URI']) ? $1 : env['REQUEST_URI'] # Remove domain, which webrick puts into the request_uri.
      else  # REQUEST_URI is blank under IIS - get this from PATH_INFO and SCRIPT_NAME
        script_filename = env["SCRIPT_NAME"].to_s.match(%r{[^/]+$})
        request_uri = env["PATH_INFO"]
        request_uri.sub!(/#{script_filename}\//, '') unless script_filename.nil?
        request_uri += '?' + env["QUERY_STRING"] unless env["QUERY_STRING"].nil? || env["QUERY_STRING"].empty?
        return request_uri
      end
     end

    def protocol
      env["HTTPS"] == "on" ? 'https://' : 'http://'
    end

    def ssl?
      protocol == 'https://'
    end
  
    # Returns the interpreted path to requested resource after all the installation directory of this application was taken into account
    def path
      path = (uri = request_uri) ? uri.split('?').first : ''
      path[relative_url_root.length..-1] # cut off the part of the url which leads to the installation directory of this app
    end    
    
    # Returns the path minus the web server relative installation directory
    def relative_url_root(force_reload = false)
      @@relative_url_root ||= File.dirname(env["SCRIPT_NAME"].to_s).gsub(/(^\.$|^\/$)/, '')
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
  
    def path_parameters=(parameters)
      @path_parameters = parameters
      @parameters = nil
    end

    def path_parameters
      @path_parameters ||= {}
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
