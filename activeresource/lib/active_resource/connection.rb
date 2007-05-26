require 'net/https'
require 'date'
require 'time'
require 'uri'
require 'benchmark'

module ActiveResource
  class ConnectionError < StandardError
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      "Failed with #{response.code}"
    end
  end

  class ClientError < ConnectionError;  end  # 4xx Client Error
  class ResourceNotFound < ClientError; end  # 404 Not Found
  class ResourceConflict < ClientError; end  # 409 Conflict

  class ServerError < ConnectionError;  end  # 5xx Server Error

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError
    def allowed_methods
      @response['Allow'].split(',').map { |verb| verb.strip.downcase.to_sym }
    end
  end

  # Class to handle connections to remote services.
  class Connection
    attr_reader :site

    class << self
      def requests
        @@requests ||= []
      end
      
      def default_header
        class << self ; attr_reader :default_header end
        @default_header = { 'Content-Type' => 'application/xml' }
      end
    end

    def initialize(site)
      raise ArgumentError, 'Missing site URI' unless site
      self.site = site
    end

    # Set URI for remote service.
    def site=(site)
      @site = site.is_a?(URI) ? site : URI.parse(site)
    end

    # Execute a GET request.
    # Used to get (find) resources.
    def get(path, headers = {})
      xml_from_response(request(:get, path, build_request_headers(headers)))
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, headers = {})
      request(:delete, path, build_request_headers(headers))
    end

    # Execute a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, body = '', headers = {})
      request(:put, path, body, build_request_headers(headers))
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(path, body = '', headers = {})
      request(:post, path, body, build_request_headers(headers))
    end

    def xml_from_response(response)
      if response = from_xml_data(Hash.from_xml(response.body))
        response.first
      else
        nil
      end
    end


    private
      # Makes request to remote service.
      def request(method, path, *arguments)
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}" if logger
        result = nil
        time = Benchmark.realtime { result = http.send(method, path, *arguments) }
        logger.info "--> #{result.code} #{result.message} (#{result.body.length}b %.2fs)" % time if logger
        handle_response(result)
      end

      # Handles response and error codes from remote service.
      def handle_response(response)
        case response.code.to_i
          when 200...400
            response
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

      # Creates new (or uses currently instantiated) Net::HTTP instance for communication with
      # remote service and resources.
      def http
        unless @http
          @http             = Net::HTTP.new(@site.host, @site.port)
          @http.use_ssl     = @site.is_a?(URI::HTTPS)
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @http.use_ssl
        end

        @http
      end
      
      # Builds headers for request to remote service.
      def build_request_headers(headers)
        authorization_header.update(self.class.default_header).update(headers)
      end
      
      # Sets authorization header; authentication information is pulled from credentials provided with site URI.
      def authorization_header
        (@site.user || @site.password ? { 'Authorization' => 'Basic ' + ["#{@site.user}:#{ @site.password}"].pack('m').delete("\r\n") } : {})
      end

      def logger #:nodoc:
        ActiveResource::Base.logger
      end

      # Manipulate from_xml Hash, because xml_simple is not exactly what we
      # want for ActiveResource.
      def from_xml_data(data)
        case data
          when Hash
            if data.keys.size == 1
              case data.values.first
                when Hash  then [ from_xml_data(data.values.first) ]
                when Array then from_xml_data(data.values.first)
                else       data.values.first
              end
            else
              data.each_key { |key| data[key] = from_xml_data(data[key]) }
              data
            end
          when Array then data.collect { |val| from_xml_data(val) }
          else data
        end
      end
  end
end
