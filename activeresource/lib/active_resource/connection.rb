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
      :delete => 'Accept'
    }

    attr_reader :site, :user, :password, :timeout
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

    # Set user for remote service.
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
      request(:head, path, build_request_headers(headers))
    end


    private
      # Makes request to remote service.
      def request(method, path, *arguments)
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}" if logger
        result = nil
        time = Benchmark.realtime { result = http.send(method, path, *arguments) }
        logger.info "--> #{result.code} #{result.message} (#{result.body ? result.body.length : 0}b %.2fs)" % time if logger
        handle_response(result)
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
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
        http             = Net::HTTP.new(@site.host, @site.port)
        http.use_ssl     = @site.is_a?(URI::HTTPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl
        http.read_timeout = @timeout if @timeout # If timeout is not set, the default Net::HTTP timeout (60s) is used.
        http
      end

      def default_header
        @default_header ||= {}
      end

      # Builds headers for request to remote service.
      def build_request_headers(headers, http_method=nil)
        authorization_header.update(default_header).update(headers).update(http_format_header(http_method))
      end

      # Sets authorization header
      def authorization_header
        (@user || @password ? { 'Authorization' => 'Basic ' + ["#{@user}:#{ @password}"].pack('m').delete("\r\n") } : {})
      end

      def http_format_header(http_method)
        {HTTP_FORMAT_HEADER_NAMES[http_method] => format.mime_type}
      end

      def logger #:nodoc:
        ActiveResource::Base.logger
      end
  end
end
