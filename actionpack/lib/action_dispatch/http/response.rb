require 'digest/md5'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/class/attribute_accessors'

module ActionDispatch # :nodoc:
  # Represents an HTTP response generated by a controller action. Use it to
  # retrieve the current state of the response, or customize the response. It can
  # either represent a real HTTP response (i.e. one that is meant to be sent
  # back to the web browser) or a TestResponse (i.e. one that is generated
  # from integration tests).
  #
  # \Response is mostly a Ruby on \Rails framework implementation detail, and
  # should never be used directly in controllers. Controllers should use the
  # methods defined in ActionController::Base instead. For example, if you want
  # to set the HTTP response's content MIME type, then use
  # ActionControllerBase#headers instead of Response#headers.
  #
  # Nevertheless, integration tests may want to inspect controller responses in
  # more detail, and that's when \Response can be useful for application
  # developers. Integration test methods such as
  # ActionDispatch::Integration::Session#get and
  # ActionDispatch::Integration::Session#post return objects of type
  # TestResponse (which are of course also of type \Response).
  #
  # For example, the following demo integration test prints the body of the
  # controller response to the console:
  #
  #  class DemoControllerTest < ActionDispatch::IntegrationTest
  #    def test_print_root_path_to_console
  #      get('/')
  #      puts @response.body
  #    end
  #  end
  class Response
    attr_accessor :request, :header
    attr_reader :status
    attr_writer :sending_file

    alias_method :headers=, :header=
    alias_method :headers,  :header

    delegate :[], :[]=, to: :@header
    delegate :each, to: :@body

    # Sets the HTTP response's content MIME type. For example, in the controller
    # you could write this:
    #
    #  response.content_type = "text/plain"
    #
    # If a character set has been defined for this response (see charset=) then
    # the character set information will also be included in the content type
    # information.
    attr_accessor :charset, :content_type

    CONTENT_TYPE = "Content-Type".freeze
    SET_COOKIE   = "Set-Cookie".freeze
    LOCATION     = "Location".freeze
 
    cattr_accessor(:default_charset) { "utf-8" }

    include Rack::Response::Helpers
    include ActionDispatch::Http::Cache::Response

    def initialize(status = 200, header = {}, body = [])
      self.body, self.header, self.status = body, header, status

      @sending_file = false
      @blank = false

      if content_type = self[CONTENT_TYPE]
        type, charset = content_type.split(/;\s*charset=/)
        @content_type = Mime::Type.lookup(type)
        @charset = charset || self.class.default_charset
      end

      prepare_cache_control!

      yield self if block_given?
    end

    def status=(status)
      @status = Rack::Utils.status_code(status)
    end

    # The response code of the request
    def response_code
      @status
    end

    # Returns a String to ensure compatibility with Net::HTTPResponse
    def code
      @status.to_s
    end

    def message
      Rack::Utils::HTTP_STATUS_CODES[@status]
    end
    alias_method :status_message, :message

    def respond_to?(method)
      if method.to_sym == :to_path
        @body.respond_to?(:to_path)
      else
        super
      end
    end

    def to_path
      @body.to_path
    end

    def body
      strings = []
      each { |part| strings << part.to_s }
      strings.join
    end

    EMPTY = " "

    def body=(body)
      @blank = true if body == EMPTY

      @body = body.respond_to?(:each) ? body : [body]
    end

    def body_parts
      @body
    end

    def set_cookie(key, value)
      ::Rack::Utils.set_cookie_header!(header, key, value)
    end

    def delete_cookie(key, value={})
      ::Rack::Utils.delete_cookie_header!(header, key, value)
    end

    def location
      headers[LOCATION]
    end
    alias_method :redirect_url, :location

    def location=(url)
      headers[LOCATION] = url
    end

    def close
      @body.close if @body.respond_to?(:close)
    end

    def to_a
      assign_default_content_type_and_charset!
      handle_conditional_get!

      @header[SET_COOKIE] = @header[SET_COOKIE].join("\n") if @header[SET_COOKIE].respond_to?(:join)

      if [204, 304].include?(@status)
        @header.delete CONTENT_TYPE
        [@status, @header, []]
      else
        [@status, @header, self]
      end
    end
    alias prepare! to_a
    alias to_ary   to_a # For implicit splat on 1.9.2

    # Returns the response cookies, converted to a Hash of (name => value) pairs
    #
    #   assert_equal 'AuthorOfNewPage', r.cookies['author']
    def cookies
      cookies = {}
      if header = self[SET_COOKIE]
        header = header.split("\n") if header.respond_to?(:to_str)
        header.each do |cookie|
          if pair = cookie.split(';').first
            key, value = pair.split("=").map { |v| Rack::Utils.unescape(v) }
            cookies[key] = value
          end
        end
      end
      cookies
    end

  private

    def assign_default_content_type_and_charset!
      return if headers[CONTENT_TYPE].present?

      @content_type ||= Mime::HTML
      @charset      ||= self.class.default_charset

      type = @content_type.to_s.dup
      type << "; charset=#{@charset}" unless @sending_file

      headers[CONTENT_TYPE] = type
    end
  end
end
