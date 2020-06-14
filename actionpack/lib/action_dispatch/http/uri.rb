# frozen_string_literal: true

class ActionDispatch::Http::URI
  mattr_accessor :tld_length, default: 1

  delegate :scheme, :host, :port, :path, :query, :to_s, to: :uri
  delegate :scheme=, :host=, :port=, :path=, :query=, to: :uri

  def initialize(uri_string)
    @uri = URI.parse(uri_string)
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

  # Returns a hash with the host and the protocol, for use with URL calls.
  def host_and_protocol
    { host: host, protocol: protocol }
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

  private
    attr_accessor :uri
end
