require 'rack/request'
require 'rack/utils'

module Rack
  # Rack::Response provides a convenient interface to create a Rack
  # response.
  #
  # It allows setting of headers and cookies, and provides useful
  # defaults (a OK response containing HTML).
  #
  # You can use Response#write to iteratively generate your response,
  # but note that this is buffered by Rack::Response until you call
  # +finish+.  +finish+ however can take a block inside which calls to
  # +write+ are syncronous with the Rack response.
  #
  # Your application's +call+ should end returning Response#finish.

  class Response
    attr_accessor :length

    def initialize(body=[], status=200, header={}, &block)
      @status = status
      @header = Utils::HeaderHash.new({"Content-Type" => "text/html"}.
                                      merge(header))

      @writer = lambda { |x| @body << x }
      @block = nil
      @length = 0

      @body = []

      if body.respond_to? :to_str
        write body.to_str
      elsif body.respond_to?(:each)
        body.each { |part|
          write part.to_s
        }
      else
        raise TypeError, "stringable or iterable required"
      end

      yield self  if block_given?
    end

    attr_reader :header
    attr_accessor :status, :body

    def [](key)
      header[key]
    end

    def []=(key, value)
      header[key] = value
    end

    def set_cookie(key, value)
      case value
      when Hash
        domain  = "; domain="  + value[:domain]    if value[:domain]
        path    = "; path="    + value[:path]      if value[:path]
        # According to RFC 2109, we need dashes here.
        # N.B.: cgi.rb uses spaces...
        expires = "; expires=" + value[:expires].clone.gmtime.
          strftime("%a, %d-%b-%Y %H:%M:%S GMT")    if value[:expires]
        secure = "; secure"  if value[:secure]
        httponly = "; HttpOnly" if value[:httponly]
        value = value[:value]
      end
      value = [value]  unless Array === value
      cookie = Utils.escape(key) + "=" +
        value.map { |v| Utils.escape v }.join("&") +
        "#{domain}#{path}#{expires}#{secure}#{httponly}"

      case self["Set-Cookie"]
      when Array
        self["Set-Cookie"] << cookie
      when String
        self["Set-Cookie"] = [self["Set-Cookie"], cookie]
      when nil
        self["Set-Cookie"] = cookie
      end
    end

    def delete_cookie(key, value={})
      unless Array === self["Set-Cookie"]
        self["Set-Cookie"] = [self["Set-Cookie"]].compact
      end

      self["Set-Cookie"].reject! { |cookie|
        cookie =~ /\A#{Utils.escape(key)}=/
      }

      set_cookie(key,
                 {:value => '', :path => nil, :domain => nil,
                   :expires => Time.at(0) }.merge(value))
    end

    def redirect(target, status=302)
      self.status = status
      self["Location"] = target
    end

    def finish(&block)
      @block = block

      if [204, 304].include?(status.to_i)
        header.delete "Content-Type"
        [status.to_i, header.to_hash, []]
      else
        [status.to_i, header.to_hash, self]
      end
    end
    alias to_a finish           # For *response

    def each(&callback)
      @body.each(&callback)
      @writer = callback
      @block.call(self)  if @block
    end

    # Append to body and update Content-Length.
    #
    # NOTE: Do not mix #write and direct #body access!
    #
    def write(str)
      s = str.to_s
      @length += Rack::Utils.bytesize(s)
      @writer.call s

      header["Content-Length"] = @length.to_s
      str
    end

    def close
      body.close if body.respond_to?(:close)
    end

    def empty?
      @block == nil && @body.empty?
    end

    alias headers header

    module Helpers
      def invalid?;       @status < 100 || @status >= 600;       end

      def informational?; @status >= 100 && @status < 200;       end
      def successful?;    @status >= 200 && @status < 300;       end
      def redirection?;   @status >= 300 && @status < 400;       end
      def client_error?;  @status >= 400 && @status < 500;       end
      def server_error?;  @status >= 500 && @status < 600;       end

      def ok?;            @status == 200;                        end
      def forbidden?;     @status == 403;                        end
      def not_found?;     @status == 404;                        end

      def redirect?;      [301, 302, 303, 307].include? @status; end
      def empty?;         [201, 204, 304].include?      @status; end

      # Headers
      attr_reader :headers, :original_headers

      def include?(header)
        !!headers[header]
      end

      def content_type
        headers["Content-Type"]
      end

      def content_length
        cl = headers["Content-Length"]
        cl ? cl.to_i : cl
      end

      def location
        headers["Location"]
      end
    end

    include Helpers
  end
end
