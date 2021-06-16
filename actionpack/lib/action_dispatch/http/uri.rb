# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require 'byebug'
require 'uri/generic'

module ActionDispatch
  module Http
    class URI
      IP_HOST_REGEXP  = /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/

      mattr_accessor :tld_length, default: 1
      attr :core_uri

      delegate :scheme, :host, :port, :path, :query, :fragment, :to_s, to: :core_uri
      delegate :scheme=, :host=, :port=, :path=, :query=, :fragment= , to: :core_uri

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

        def named_host?(host)
          !IP_HOST_REGEXP.match?(host)
        end

        private
          def extract_domain_from(host, tld_length)
            host.split(".").last(1 + tld_length).join(".")
          end

          def extract_subdomains_from(host, tld_length)
            return [] if host.blank?
            parts = host.split(".")
            parts[0..-(tld_length + 2)]
          end

      end

      def initialize(uri)
        @core_uri = uri
      end

      def self.build_from_hash(scheme:, host:, path:, port:)
        host = nil if host == ':' || host.blank?
        new(::URI::Generic.build2(scheme: scheme, host: host, path: path))
      end

      def self.build_from_faulty_string(url_string)
        if ipv6 = url_string.match(/([https]*)[:\/]*((?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4})(.*)/)
          new(::URI::Generic.build2(scheme: ipv6[1], host: ipv6[2], path: ipv6[3]))
        else
          # handle other edge cases
          url_string = "" if url_string == ':' 
          new(::URI.parse(url_string)) rescue nil
        end
      end

      def self.build_from_string(url_string)
        new(::URI.parse(url_string))
      end

      def protocol
        "#{scheme}://"
      end

      # Returns a \host:\port string for this request, such as "example.com" or
      # "example.com:8080". Port is only included if it is not a default port
      # (80 or 443).
      def host_with_port
        "#{host}#{port_string}"
      end

      # Returns a string \port suffix, including colon, like ":8080" if the \port
      # number of this request is not the default HTTP \port 80 or HTTPS \port 443.
      def port_string
        standard_port? ? "" : ":#{port}"
      end

      # Returns the standard \port number for this request's protocol.
      def standard_port
        scheme == "https" ? 443 : 80
      end

      # Returns whether this request is using the standard port.
      def standard_port?
        port == standard_port
      end
       
      # Returns a number \port suffix like 8080 if the \port number of this request
      # is not the default HTTP \port 80 or HTTPS \port 443.
      def optional_port
        standard_port? ? nil : port
      end

      # Returns a hash with the host and the protocol, for use with URL calls.
      def host_and_protocol
        { host: host, protocol: protocol }
      end

      # Returns the \domain part of a \host, such as "rubyonrails.org" in "www.rubyonrails.org". You can specify
      # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
      def domain(tld_length = @@tld_length)
        self.class.extract_domain(host, tld_length)
      end

      # Returns all the \subdomains as an array, so <tt>["dev", "www"]</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>["www"]</tt> instead of <tt>["www", "rubyonrails"]</tt>
      # in "www.rubyonrails.co.uk".
      def subdomains(tld_length = @@tld_length)
        self.class.extract_subdomains(host, tld_length)
      end

      # Returns all the \subdomains as a string, so <tt>"dev.www"</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>"www"</tt> instead of <tt>"www.rubyonrails"</tt>
      # in "www.rubyonrails.co.uk".
      def subdomain(tld_length = @@tld_length)
        self.class.extract_subdomains(host, tld_length).join('.')
      end

      def extract_domain_from(host, tld_length)
        self.class.extract_domain_from(host, tld_length)
      end

      private
        attr_accessor :uri
    end

  end
end
