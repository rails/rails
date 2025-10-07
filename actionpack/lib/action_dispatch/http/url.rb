# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/module/attribute_accessors"

module ActionDispatch
  module Http
    module URL
      IP_HOST_REGEXP  = /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
      HOST_REGEXP     = /(^[^:]+:\/\/)?(\[[^\]]+\]|[^:]+)(?::(\d+$))?/
      PROTOCOL_REGEXP = /^([^:]+)(:)?(\/\/)?$/

      # DomainExtractor provides utility methods for extracting domain and subdomain
      # information from host strings. This module is used internally by Action Dispatch
      # to parse host names and separate the domain from subdomains based on the
      # top-level domain (TLD) length.
      #
      # The module assumes a standard domain structure where domains consist of:
      # - Subdomains (optional, can be multiple levels)
      # - Domain name
      # - Top-level domain (TLD, can be multiple levels like .co.uk)
      #
      # For example, in "api.staging.example.co.uk":
      # - Subdomains: ["api", "staging"]
      # - Domain: "example.co.uk" (with tld_length=2)
      # - TLD: "co.uk"
      module DomainExtractor
        extend self

        # Extracts the domain part from a host string, including the specified
        # number of top-level domain components.
        #
        # The domain includes the main domain name plus the TLD components.
        # The +tld_length+ parameter specifies how many components from the right
        # should be considered part of the TLD.
        #
        # ==== Parameters
        #
        # [+host+]
        #   The host string to extract the domain from.
        #
        # [+tld_length+]
        #   The number of domain components that make up the TLD. For example,
        #   use 1 for ".com" or 2 for ".co.uk".
        #
        # ==== Examples
        #
        #   # Standard TLD (tld_length = 1)
        #   DomainExtractor.domain_from("www.example.com", 1)
        #   # => "example.com"
        #
        #   # Country-code TLD (tld_length = 2)
        #   DomainExtractor.domain_from("www.example.co.uk", 2)
        #   # => "example.co.uk"
        #
        #   # Multiple subdomains
        #   DomainExtractor.domain_from("api.staging.myapp.herokuapp.com", 1)
        #   # => "herokuapp.com"
        #
        #   # Single component (returns the host itself)
        #   DomainExtractor.domain_from("localhost", 1)
        #   # => "localhost"
        def domain_from(host, tld_length)
          host.split(".").last(1 + tld_length).join(".")
        end

        # Extracts the subdomain components from a host string as an Array.
        #
        # Returns all the components that come before the domain and TLD parts.
        # The +tld_length+ parameter is used to determine where the domain begins
        # so that everything before it is considered a subdomain.
        #
        # ==== Parameters
        #
        # [+host+]
        #   The host string to extract subdomains from.
        #
        # [+tld_length+]
        #   The number of domain components that make up the TLD. This affects
        #   where the domain boundary is calculated.
        #
        # ==== Examples
        #
        #   # Standard TLD (tld_length = 1)
        #   DomainExtractor.subdomains_from("www.example.com", 1)
        #   # => ["www"]
        #
        #   # Country-code TLD (tld_length = 2)
        #   DomainExtractor.subdomains_from("api.staging.example.co.uk", 2)
        #   # => ["api", "staging"]
        #
        #   # No subdomains
        #   DomainExtractor.subdomains_from("example.com", 1)
        #   # => []
        #
        #   # Single subdomain with complex TLD
        #   DomainExtractor.subdomains_from("www.mysite.co.uk", 2)
        #   # => ["www"]
        #
        #   # Multiple levels of subdomains
        #   DomainExtractor.subdomains_from("dev.api.staging.example.com", 1)
        #   # => ["dev", "api", "staging"]
        def subdomains_from(host, tld_length)
          parts = host.split(".")
          parts[0..-(tld_length + 2)]
        end
      end

      mattr_accessor :secure_protocol, default: false
      mattr_accessor :tld_length, default: 1
      mattr_accessor :domain_extractor, default: DomainExtractor

      class << self
        # Returns the domain part of a host given the domain level.
        #
        #     # Top-level domain example
        #     extract_domain('www.example.com', 1) # => "example.com"
        #     # Second-level domain example
        #     extract_domain('dev.www.example.co.uk', 2) # => "example.co.uk"
        def extract_domain(host, tld_length)
          extract_domain_from(host, tld_length) if named_host?(host)
        end

        # Returns the subdomains of a host as an Array given the domain level.
        #
        #     # Top-level domain example
        #     extract_subdomains('www.example.com', 1) # => ["www"]
        #     # Second-level domain example
        #     extract_subdomains('dev.www.example.co.uk', 2) # => ["dev", "www"]
        def extract_subdomains(host, tld_length)
          if named_host?(host)
            extract_subdomains_from(host, tld_length)
          else
            []
          end
        end

        # Returns the subdomains of a host as a String given the domain level.
        #
        #     # Top-level domain example
        #     extract_subdomain('www.example.com', 1) # => "www"
        #     # Second-level domain example
        #     extract_subdomain('dev.www.example.co.uk', 2) # => "dev.www"
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

          path = "/" if options[:trailing_slash] && path.blank?

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
            domain_extractor.domain_from(host, tld_length)
          end

          def extract_subdomains_from(host, tld_length)
            domain_extractor.subdomains_from(host, tld_length)
          end

          def build_host_url(host, port, protocol, options, path)
            if match = host.match(HOST_REGEXP)
              protocol_from_host = match[1] if protocol.nil?
              host               = match[2]
              port               = match[3] unless options.key? :port
            end

            protocol = protocol_from_host || normalize_protocol(protocol).dup
            host     = normalize_host(host, options)
            port     = normalize_port(port, protocol)

            result = protocol

            if options[:user] && options[:password]
              result << "#{Rack::Utils.escape(options[:user])}:#{Rack::Utils.escape(options[:password])}@"
            end

            result << host

            result << ":" << port.to_s if port

            result.concat path
          end

          def named_host?(host)
            !IP_HOST_REGEXP.match?(host)
          end

          def normalize_protocol(protocol)
            case protocol
            when nil
              secure_protocol ? "https://" : "http://"
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
            when "//" then port
            when "https://"
              port unless port.to_i == 443
            else
              port unless port.to_i == 80
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
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #     req.url # => "http://example.com"
      def url
        protocol + host_with_port + fullpath
      end

      # Returns 'https://' if this is an SSL request and 'http://' otherwise.
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #     req.protocol # => "http://"
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com', 'HTTPS' => 'on'
      #     req.protocol # => "https://"
      def protocol
        @protocol ||= ssl? ? "https://" : "http://"
      end

      # Returns the host and port for this request, such as "example.com:8080".
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #     req.raw_host_with_port # => "example.com"
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #     req.raw_host_with_port # => "example.com:80"
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.raw_host_with_port # => "example.com:8080"
      def raw_host_with_port
        if forwarded = x_forwarded_host.presence
          forwarded.split(/,\s?/).last
        else
          get_header("HTTP_HOST") || "#{server_name}:#{get_header('SERVER_PORT')}"
        end
      end

      # Returns the host for this request, such as "example.com".
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.host # => "example.com"
      def host
        raw_host_with_port.sub(/:\d+$/, "")
      end

      # Returns a host:port string for this request, such as "example.com" or
      # "example.com:8080". Port is only included if it is not a default port (80 or
      # 443)
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #     req.host_with_port # => "example.com"
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #     req.host_with_port # => "example.com"
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.host_with_port # => "example.com:8080"
      def host_with_port
        "#{host}#{port_string}"
      end

      # Returns the port number of this request as an integer.
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com'
      #     req.port # => 80
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.port # => 8080
      def port
        @port ||= if raw_host_with_port =~ /:(\d+)$/
          $1.to_i
        else
          standard_port
        end
      end

      # Returns the standard port number for this request's protocol.
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.standard_port # => 80
      def standard_port
        if "https://" == protocol
          443
        else
          80
        end
      end

      # Returns whether this request is using the standard port.
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #     req.standard_port? # => true
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.standard_port? # => false
      def standard_port?
        port == standard_port
      end

      # Returns a number port suffix like 8080 if the port number of this request is
      # not the default HTTP port 80 or HTTPS port 443.
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #     req.optional_port # => nil
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.optional_port # => 8080
      def optional_port
        standard_port? ? nil : port
      end

      # Returns a string port suffix, including colon, like ":8080" if the port number
      # of this request is not the default HTTP port 80 or HTTPS port 443.
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:80'
      #     req.port_string # => ""
      #
      #     req = ActionDispatch::Request.new 'HTTP_HOST' => 'example.com:8080'
      #     req.port_string # => ":8080"
      def port_string
        standard_port? ? "" : ":#{port}"
      end

      # Returns the requested port, such as 8080, based on SERVER_PORT.
      #
      #     req = ActionDispatch::Request.new 'SERVER_PORT' => '80'
      #     req.server_port # => 80
      #
      #     req = ActionDispatch::Request.new 'SERVER_PORT' => '8080'
      #     req.server_port # => 8080
      def server_port
        get_header("SERVER_PORT").to_i
      end

      # Returns the domain part of a host, such as "rubyonrails.org" in
      # "www.rubyonrails.org". You can specify a different `tld_length`, such as 2 to
      # catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
      def domain(tld_length = @@tld_length)
        ActionDispatch::Http::URL.extract_domain(host, tld_length)
      end

      # Returns all the subdomains as an array, so `["dev", "www"]` would be returned
      # for "dev.www.rubyonrails.org". You can specify a different `tld_length`, such
      # as 2 to catch `["www"]` instead of `["www", "rubyonrails"]` in
      # "www.rubyonrails.co.uk".
      def subdomains(tld_length = @@tld_length)
        ActionDispatch::Http::URL.extract_subdomains(host, tld_length)
      end

      # Returns all the subdomains as a string, so `"dev.www"` would be returned for
      # "dev.www.rubyonrails.org". You can specify a different `tld_length`, such as 2
      # to catch `"www"` instead of `"www.rubyonrails"` in "www.rubyonrails.co.uk".
      def subdomain(tld_length = @@tld_length)
        ActionDispatch::Http::URL.extract_subdomain(host, tld_length)
      end
    end
  end
end
