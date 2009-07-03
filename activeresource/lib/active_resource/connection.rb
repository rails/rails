require 'active_support/core_ext/benchmark'
require 'net/https'
require 'date'
require 'time'
require 'uri'

module ActiveResource
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
    def initialize(site, format = ActiveResource::Formats::XmlFormat)
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

    # Sets the user for remote service.
    def user=(user)
      @user = user
    end

    # Sets the password for remote service.
    def password=(password)
      @password = password
    end

    # Sets the number of seconds after which HTTP requests to the remote service should time out.
    def timeout=(timeout)
      @timeout = timeout
    end

    # Executes a GET request.
    # Used to get (find) resources.
    def get(path, headers = {})
      format.decode(request(:get, path, build_request_headers(headers, :get)).body)
    end

    # Executes a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, headers = {})
      request(:delete, path, build_request_headers(headers, :delete))
    end

    # Executes a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, body = '', headers = {})
      request(:put, path, body.to_s, build_request_headers(headers, :put))
    end

    # Executes a POST request.
    # Used to create new resources.
    def post(path, body = '', headers = {})
      request(:post, path, body.to_s, build_request_headers(headers, :post))
    end

    # Executes a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, headers = {})
      request(:head, path, build_request_headers(headers))
    end


    private
      # Makes a request to the remote service.
      def request(method, path, *arguments)
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}" if logger
        result = nil
        ms = Benchmark.ms { result = http.send(method, path, *arguments) }
        logger.info "--> %d %s (%d %.0fms)" % [result.code, result.message, result.body ? result.body.length : 0, ms] if logger
        handle_response(result)
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      end

      # Handles response and error codes from the remote service.
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

      # Creates new Net::HTTP instance for communication with the
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
