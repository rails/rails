module ActionDispatch
  module Http
    module URL
      # Returns the complete URL used for this request.
      def url
        protocol + host_with_port + request_uri
      end

      # Returns 'https://' if this is an SSL request and 'http://' otherwise.
      def protocol
        ssl? ? 'https://' : 'http://'
      end

      # Is this an SSL request?
      def ssl?
        @env['HTTPS'] == 'on' || @env['HTTP_X_FORWARDED_PROTO'] == 'https'
      end

      # Returns the \host for this request, such as "example.com".
      def raw_host_with_port
        if forwarded = env["HTTP_X_FORWARDED_HOST"]
          forwarded.split(/,\s?/).last
        else
          env['HTTP_HOST'] || "#{env['SERVER_NAME'] || env['SERVER_ADDR']}:#{env['SERVER_PORT']}"
        end
      end

      # Returns the host for this request, such as example.com.
      def host
        raw_host_with_port.sub(/:\d+$/, '')
      end

      # Returns a \host:\port string for this request, such as "example.com" or
      # "example.com:8080".
      def host_with_port
        "#{host}#{port_string}"
      end

      # Returns the port number of this request as an integer.
      def port
        if raw_host_with_port =~ /:(\d+)$/
          $1.to_i
        else
          standard_port
        end
      end

      # Returns the standard \port number for this request's protocol.
      def standard_port
        case protocol
          when 'https://' then 443
          else 80
        end
      end

      # Returns a \port suffix like ":8080" if the \port number of this request
      # is not the default HTTP \port 80 or HTTPS \port 443.
      def port_string
        port == standard_port ? '' : ":#{port}"
      end

      def server_port
        @env['SERVER_PORT'].to_i
      end

      # Returns the \domain part of a \host, such as "rubyonrails.org" in "www.rubyonrails.org". You can specify
      # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
      def domain(tld_length = 1)
        return nil unless named_host?(host)

        host.split('.').last(1 + tld_length).join('.')
      end

      # Returns all the \subdomains as an array, so <tt>["dev", "www"]</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>["www"]</tt> instead of <tt>["www", "rubyonrails"]</tt>
      # in "www.rubyonrails.co.uk".
      def subdomains(tld_length = 1)
        return [] unless named_host?(host)
        parts = host.split('.')
        parts[0..-(tld_length+2)]
      end

      # Returns the query string, accounting for server idiosyncrasies.
      def query_string
        @env['QUERY_STRING'].present? ? @env['QUERY_STRING'] : (@env['REQUEST_URI'].to_s.split('?', 2)[1] || '')
      end

      # Returns the request URI, accounting for server idiosyncrasies.
      # WEBrick includes the full URL. IIS leaves REQUEST_URI blank.
      def request_uri
        if uri = @env['REQUEST_URI']
          # Remove domain, which webrick puts into the request_uri.
          (%r{^\w+\://[^/]+(/.*|$)$} =~ uri) ? $1 : uri
        else
          # Construct IIS missing REQUEST_URI from SCRIPT_NAME and PATH_INFO.
          uri = @env['PATH_INFO'].to_s

          if script_filename = @env['SCRIPT_NAME'].to_s.match(%r{[^/]+$})
            uri = uri.sub(/#{script_filename}\//, '')
          end

          env_qs = @env['QUERY_STRING'].to_s
          uri += "?#{env_qs}" unless env_qs.empty?

          if uri.blank?
            @env.delete('REQUEST_URI')
          else
            @env['REQUEST_URI'] = uri
          end
        end
      end

      # Returns the interpreted \path to requested resource after all the installation
      # directory of this application was taken into account.
      def path
        path = request_uri.to_s[/\A[^\?]*/]
        path.sub!(/\A#{ActionController::Base.relative_url_root}/, '')
        path
      end

    private

      def named_host?(host)
        !(host.nil? || /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(host))
      end
    end
  end
end