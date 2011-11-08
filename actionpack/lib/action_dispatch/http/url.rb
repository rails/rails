module ActionDispatch
  module Http
    module URL
      mattr_accessor :tld_length
      self.tld_length = 1

      class << self
        def extract_domain(host, tld_length = @@tld_length)
          return nil unless named_host?(host)
          host.split('.').last(1 + tld_length).join('.')
        end

        def extract_subdomains(host, tld_length = @@tld_length)
          return [] unless named_host?(host)
          parts = host.split('.')
          parts[0..-(tld_length+2)]
        end

        def extract_subdomain(host, tld_length = @@tld_length)
          extract_subdomains(host, tld_length).join('.')
        end

        def url_for(options = {})
          unless options[:host].present? || options[:only_path].present?
            raise ArgumentError, 'Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true'
          end

          rewritten_url = ""

          unless options[:only_path]
            unless options[:protocol] == false
              rewritten_url << (options[:protocol] || "http")
              rewritten_url << ":" unless rewritten_url.match(%r{:|//})
            end
            rewritten_url << "//" unless rewritten_url.match("//")
            rewritten_url << rewrite_authentication(options)
            rewritten_url << host_or_subdomain_and_domain(options)
            rewritten_url << ":#{options.delete(:port)}" if options[:port]
          end

          path = options.delete(:path) || ''

          params = options[:params] || {}
          params.reject! {|k,v| v.to_param.nil? }

          rewritten_url << (options[:trailing_slash] ? path.sub(/\?|\z/) { "/" + $& } : path)
          rewritten_url << "?#{params.to_query}" unless params.empty?
          rewritten_url << "##{Rack::Mount::Utils.escape_uri(options[:anchor].to_param.to_s)}" if options[:anchor]
          rewritten_url
        end

        private

        def named_host?(host)
          !(host.nil? || /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(host))
        end

        def rewrite_authentication(options)
          if options[:user] && options[:password]
            "#{Rack::Utils.escape(options[:user])}:#{Rack::Utils.escape(options[:password])}@"
          else
            ""
          end
        end

        def host_or_subdomain_and_domain(options)
          return options[:host] unless (options[:subdomain] || options[:domain]) && named_host?(options[:host])

          tld_length = options[:tld_length] || @@tld_length

          host = ""
          host << (options[:subdomain] || extract_subdomain(options[:host], tld_length))
          host << "."
          host << (options[:domain]    || extract_domain(options[:host], tld_length))
          host
        end
      end

      # Returns the complete URL used for this request.
      def url
        protocol + host_with_port + fullpath
      end

      # Returns 'https://' if this is an SSL request and 'http://' otherwise.
      def protocol
        @protocol ||= ssl? ? 'https://' : 'http://'
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
        @port ||= begin
          if raw_host_with_port =~ /:(\d+)$/
            $1.to_i
          else
            standard_port
          end
        end
      end

      # Returns the standard \port number for this request's protocol.
      def standard_port
        case protocol
          when 'https://' then 443
          else 80
        end
      end

      # Returns whether this request is using the standard port
      def standard_port?
        port == standard_port
      end

      # Returns a number \port suffix like 8080 if the \port number of this request
      # is not the default HTTP \port 80 or HTTPS \port 443.
      def optional_port
        standard_port? ? nil : port
      end

      # Returns a string \port suffix, including colon, like ":8080" if the \port
      # number of this request is not the default HTTP \port 80 or HTTPS \port 443.
      def port_string
        standard_port? ? '' : ":#{port}"
      end

      def server_port
        @env['SERVER_PORT'].to_i
      end

      # Returns the \domain part of a \host, such as "rubyonrails.org" in "www.rubyonrails.org". You can specify
      # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
      def domain(tld_length = @@tld_length)
        ActionDispatch::Http::URL.extract_domain(host, tld_length)
      end

      # Returns all the \subdomains as an array, so <tt>["dev", "www"]</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>["www"]</tt> instead of <tt>["www", "rubyonrails"]</tt>
      # in "www.rubyonrails.co.uk".
      def subdomains(tld_length = @@tld_length)
        ActionDispatch::Http::URL.extract_subdomains(host, tld_length)
      end

      # Returns all the \subdomains as a string, so <tt>"dev.www"</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>"www"</tt> instead of <tt>"www.rubyonrails"</tt>
      # in "www.rubyonrails.co.uk".
      def subdomain(tld_length = @@tld_length)
        subdomains(tld_length).join(".")
      end
    end
  end
end
