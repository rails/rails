require 'net/https'
require 'date'
require 'time'
require 'uri'
require 'benchmark'

module ActiveResource
  class ConnectionError < StandardError # :nodoc:
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      "Failed with #{response.code} #{response.message if response.respond_to?(:message)}"
    end
  end

  # Raised when a Timeout::Error occurs.
  class TimeoutError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ;end
  end

  # Raised when a OpenSSL::SSL::SSLError occurs.
  class SSLError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ;end
  end

  # 3xx Redirection
  class Redirection < ConnectionError # :nodoc:
    def to_s; response['Location'] ? "#{super} => #{response['Location']}" : super; end
  end

  # 4xx Client Error
  class ClientError < ConnectionError; end # :nodoc:

  # 400 Bad Request
  class BadRequest < ClientError; end # :nodoc

  # 401 Unauthorized
  class UnauthorizedAccess < ClientError; end # :nodoc

  # 403 Forbidden
  class ForbiddenAccess < ClientError; end # :nodoc

  # 404 Not Found
  class ResourceNotFound < ClientError; end # :nodoc:

  # 409 Conflict
  class ResourceConflict < ClientError; end # :nodoc:

  # 410 Gone
  class ResourceGone < ClientError; end # :nodoc:

  # 5xx Server Error
  class ServerError < ConnectionError; end # :nodoc:

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError # :nodoc:
    def allowed_methods
      @response['Allow'].split(',').map { |verb| verb.strip.downcase.to_sym }
    end
  end

  # Class to handle connections to remote web services.
  # This class is used by ActiveResource::Base to interface with REST
  # services.
  class Connection

    HTTP_FORMAT_HEADER_NAMES = {  :get => 'Accept',
      :put => 'Content-Type',
      :post => 'Content-Type',
      :delete => 'Accept',
      :head => 'Accept'
    }

    attr_reader :site, :user, :password, :timeout, :proxy, :ssl_options
    attr_accessor :format

    class << self
      def requests
        @@requests ||= []
      end
    end

    # The +site+ parameter is required and will set the +site+
    # attribute to the URI for the remote resource service.
    def initialize(site, format = ActiveResource::Formats[:xml])
      raise ArgumentError, 'Missing site URI' unless site
      @user = @password = nil
      self.site = site
      self.format = format
    end

    # Set URI for remote service.
    def site=(site)
      @site = site.is_a?(URI) ? site : URI.parse(site)
      @user = URI.decode(@site.user) if @site.user
      @password = URI.decode(@site.password) if @site.password
    end

    # Set the proxy for remote service.
    def proxy=(proxy)
      @proxy = proxy.is_a?(URI) ? proxy : URI.parse(proxy)
    end

    # Set the user for remote service.
    def user=(user)
      @user = user
    end

    # Set password for remote service.
    def password=(password)
      @password = password
    end

    # Set the number of seconds after which HTTP requests to the remote service should time out.
    def timeout=(timeout)
      @timeout = timeout
    end

    # Hash of options applied to Net::HTTP instance when +site+ protocol is 'https'.
    def ssl_options=(opts={})
      @ssl_options = opts
    end

    # Execute a GET request.
    # Used to get (find) resources.
    def get(path, headers = {})
      format.decode(request(:get, path, build_request_headers(headers, :get)).body)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, headers = {})
      request(:delete, path, build_request_headers(headers, :delete))
    end

    # Execute a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, body = '', headers = {})
      request(:put, path, body.to_s, build_request_headers(headers, :put))
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(path, body = '', headers = {})
      request(:post, path, body.to_s, build_request_headers(headers, :post))
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, headers = {})
      request(:head, path, build_request_headers(headers, :head))
    end


    private
      # Makes request to remote service.
      def request(method, path, *arguments)
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}" if logger
        result = nil
        ms = Benchmark.ms { result = http.send(method, path, *arguments) }
        logger.info "--> %d %s (%d %.0fms)" % [result.code, result.message, result.body ? result.body.length : 0, ms] if logger
        handle_response(result)
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError.new(e.message)
      end

      # Handles response and error codes from remote service.
      def handle_response(response)
        case response.code.to_i
          when 301,302
            raise(Redirection.new(response))
          when 200...400
            response
          when 400
            raise(BadRequest.new(response))
          when 401
            raise(UnauthorizedAccess.new(response))
          when 403
            raise(ForbiddenAccess.new(response))
          when 404
            raise(ResourceNotFound.new(response))
          when 405
            raise(MethodNotAllowed.new(response))
          when 409
            raise(ResourceConflict.new(response))
          when 410
            raise(ResourceGone.new(response))
          when 422
            raise(ResourceInvalid.new(response))
          when 401...500
            raise(ClientError.new(response))
          when 500...600
            raise(ServerError.new(response))
          else
            raise(ConnectionError.new(response, "Unknown response code: #{response.code}"))
        end
      end

      # Creates new Net::HTTP instance for communication with
      # remote service and resources.
      def http
        configure_http(new_http)
      end

      def new_http
        if @proxy
          Net::HTTP.new(@site.host, @site.port, @proxy.host, @proxy.port, @proxy.user, @proxy.password)
        else
          Net::HTTP.new(@site.host, @site.port)
        end
      end

      def configure_http(http)
        http = apply_ssl_options(http)

        # Net::HTTP timeouts default to 60 seconds.
        if @timeout
          http.open_timeout = @timeout
          http.read_timeout = @timeout
        end

        http
      end

      def apply_ssl_options(http)
        return http unless @site.is_a?(URI::HTTPS)

        http.use_ssl     = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        return http unless defined?(@ssl_options)

        http.ca_path     = @ssl_options[:ca_path] if @ssl_options[:ca_path]
        http.ca_file     = @ssl_options[:ca_file] if @ssl_options[:ca_file]

        http.cert        = @ssl_options[:cert] if @ssl_options[:cert]
        http.key         = @ssl_options[:key]  if @ssl_options[:key]

        http.cert_store  = @ssl_options[:cert_store]  if @ssl_options[:cert_store]
        http.ssl_timeout = @ssl_options[:ssl_timeout] if @ssl_options[:ssl_timeout]

        http.verify_mode     = @ssl_options[:verify_mode]     if @ssl_options[:verify_mode]
        http.verify_callback = @ssl_options[:verify_callback] if @ssl_options[:verify_callback]
        http.verify_depth    = @ssl_options[:verify_depth]    if @ssl_options[:verify_depth]

        http
      end

      def default_header
        @default_header ||= {}
      end

      # Builds headers for request to remote service.
      def build_request_headers(headers, http_method=nil)
        authorization_header.update(default_header).update(http_format_header(http_method)).update(headers)
      end

      # Sets authorization header
      def authorization_header
        (@user || @password ? { 'Authorization' => 'Basic ' + ["#{@user}:#{ @password}"].pack('m').delete("\r\n") } : {})
      end

      def http_format_header(http_method)
        {HTTP_FORMAT_HEADER_NAMES[http_method] => format.mime_type}
      end

      def logger #:nodoc:
        Base.logger
      end
  end
end
