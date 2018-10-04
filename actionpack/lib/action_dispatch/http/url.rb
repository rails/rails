# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActionDispatch
  module Http
    module URL
      IP_HOST_REGEXP  = /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
      HOST_REGEXP     = /(^[^:]+:\/\/)?(\[[^\]]+\]|[^:]+)(?::(\d+$))?/
      PROTOCOL_REGEXP = /^([^:]+)(:)?(\/\/)?$/

      mattr_accessor :tld_length, default: 1

      class << self
        # Returns the domain part of a host given the domain level.
        #
        #    # Top-level domain example
        #    extract_domain('www.example.com', 1) # => "example.com"
        #    # Second-level domain example
        #    extract_domain('dev.www.example.co.uk', 2) # => "example.co.uk"
        def extract_domain(host, tld_length)
          extract_domain_from(host, tld_length) if named_host?(host)
        end

        # Returns the subdomains of a host as an Array given the domain level.
        #
        #    # Top-level domain example
        #    extract_subdomains('www.example.com', 1) # => ["www"]
        #    # Second-level domain example
        #    extract_subdomains('dev.www.example.co.uk', 2) # => ["dev", "www"]
        def extract_subdomains(host, tld_length)
          if named_host?(host)
            extract_subdomains_from(host, tld_length)
          else
            []
          end
        end

        # Returns the subdomains of a host as a String given the domain level.
        #
        #    # Top-level domain example
        #    extract_subdomain('www.example.com', 1) # => "www"
        #    # Second-level domain example
        #    extract_subdomain('dev.www.example.co.uk', 2) # => "dev.www"
        def extract_subdomain(host, tld_length)
          extract_subdomains(host, tld_length).join(".")
        end

        def url_for(options)
          if options[:only_path]
            path_for options
          else
            full_url_for options
          end
        end

        def full_url_for(options)
          host     = options[:host]
          protocol = options[:protocol]
          port     = options[:port]

          unless host
            raise ArgumentError, "Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true"
          end

          build_host_url(host, port, protocol, options, path_for(options))
        end

        def path_for(options)
          path = options[:script_name].to_s.chomp("/")
          path << options[:path] if options.key?(:path)

          add_trailing_slash(path) if options[:trailing_slash]
          add_params(path, options[:params]) if options.key?(:params)
          add_anchor(path, options[:anchor]) if options.key?(:anchor)

          path
        end

        private

        def add_params(path, params)
          params = { params: params } unless params.is_a?(Hash)
          params.reject! { |_, v| v.to_param.nil? }
          query = params.to_query
          path << "?#{query}" unless query.empty?
        end

        def add_anchor(path, anchor)
          if anchor
            path << "##{Journey::Router::Utils.escape_fragment(anchor.to_param)}"
          end
        end

        def extract_domain_from(host, tld_length)
          host.split(".").last(1 + tld_length).join(".")
        end

        def extract_subdomains_from(host, tld_length)
          parts = host.split(".")
          parts[0..-(tld_length + 2)]
        end

        def add_trailing_slash(path)
          if path.include?("?")
            path.sub!(/\?/, '/\&')
          elsif !path.include?(".")
            path.sub!(/[^\/]\z|\A\z/, '\&/')
          end
        end

        def build_host_url(host, port, protocol, options, path)
          if match = host.match(HOST_REGEXP)
            protocol ||= match[1] unless protocol == false
            host       = match[2]
            port       = match[3] unless options.key? :port
          end

          protocol = normalize_protocol protocol
          host     = normalize_host(host, options)

          result = protocol.dup

          if options[:user] && options[:password]
            result << "#{Rack::Utils.escape(options[:user])}:#{Rack::Utils.escape(options[:password])}@"
          end

          result << host
          normalize_port(port, protocol) { |normalized_port|
            result << ":#{normalized_port}"
          }

          result.concat path
        end

        def named_host?(host)
          IP_HOST_REGEXP !~ host
        end

        def normalize_protocol(protocol)
          case protocol
          when nil
            "http://"
          when false, "//"
            "//"
          when PROTOCOL_REGEXP
            "#{$1}://"
          else
            raise ArgumentError, "Invalid :protocol option: #{protocol.inspect}"
          end
        end

        def normalize_host(_host, options)
          return _host unless named_host?(_host)

          tld_length = options[:tld_length] || @@tld_length
          subdomain  = options.fetch :subdomain, true
          domain     = options[:domain]

          host = +""
          if subdomain == true
            return _host if domain.nil?

            host << extract_subdomains_from(_host, tld_length).join(".")
          elsif subdomain
            host << subdomain.to_param
          end
          host << "." unless host.empty?
          host << (domain || extract_domain_from(_host, tld_length))
          host
        end

        def normalize_port(port, protocol)
          return unless port

          case protocol
          when "//" then yield port
          when "https://"
            yield port unless port.to_i == 443
          else
            yield port unless port.to_i == 80
          end
        end
      end

      def initialize
        super
        @protocol = nil
        @port     = nil
      end

      # Returns the complete URL used for this request.
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #   req.url # => "http://example.com"
      def url
        protocol + host_with_port + fullpath
      end

      # Returns 'https://' if this is an SSL request and 'http://' otherwise.
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #   req.protocol # => "http://"
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com', 'HTTPS' => 'on'
      #   req.protocol # => "https://"
      def protocol
        @protocol ||= ssl? ? "https://" : "http://"
      end

      # Returns the \host and port for this request, such as "example.com:8080".
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #   req.raw_host_with_port # => "example.com"
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #   req.raw_host_with_port # => "example.com:80"
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.raw_host_with_port # => "example.com:8080"
      def raw_host_with_port
        if forwarded = x_forwarded_host.presence
          forwarded.split(/,\s?/).last
        else
          get_header("HTTP_HOST") || "#{server_name || server_addr}:#{get_header('SERVER_PORT')}"
        end
      end

      # Returns the host for this request, such as "example.com".
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.host # => "example.com"
      def host
        raw_host_with_port.sub(/:\d+$/, "")
      end

      # Returns a \host:\port string for this request, such as "example.com" or
      # "example.com:8080". Port is only included if it is not a default port
      # (80 or 443)
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #   req.host_with_port # => "example.com"
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #   req.host_with_port # => "example.com"
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.host_with_port # => "example.com:8080"
      def host_with_port
        "#{host}#{port_string}"
      end

      # Returns the port number of this request as an integer.
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #   req.port # => 80
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.port # => 8080
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
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.standard_port # => 80
      def standard_port
        case protocol
        when "https://" then 443
        else 80
        end
      end

      # Returns whether this request is using the standard port
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #   req.standard_port? # => true
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.standard_port? # => false
      def standard_port?
        port == standard_port
      end

      # Returns a number \port suffix like 8080 if the \port number of this request
      # is not the default HTTP \port 80 or HTTPS \port 443.
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #   req.optional_port # => nil
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.optional_port # => 8080
      def optional_port
        standard_port? ? nil : port
      end

      # Returns a string \port suffix, including colon, like ":8080" if the \port
      # number of this request is not the default HTTP \port 80 or HTTPS \port 443.
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #   req.port_string # => ""
      #
      #   req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #   req.port_string # => ":8080"
      def port_string
        standard_port? ? "" : ":#{port}"
      end

      # Returns the requested port, such as 8080, based on SERVER_PORT
      #
      #   req = ActionDispatch::Request.new 'SERVER_PORT' => '80'
      #   req.server_port # => 80
      #
      #   req = ActionDispatch::Request.new 'SERVER_PORT' => '8080'
      #   req.server_port # => 8080
      def server_port
        get_header("SERVER_PORT").to_i
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
        ActionDispatch::Http::URL.extract_subdomain(host, tld_length)
      end
    end
  end
end
