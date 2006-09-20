require 'net/https'
require 'date'
require 'time'
require 'uri'

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


  class Connection
    attr_accessor :site

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
      @site = site
    end

    def get(path)
      Hash.from_xml(request(:get, path).body)
    end

    def delete(path)
      request(:delete, path, self.class.default_header)
    end

    def put(path, body = '')
      request(:put, path, body, self.class.default_header)
    end

    def post(path, body = '')
      request(:post, path, body, self.class.default_header)
    end

    private
      def request(method, *arguments)
        handle_response(http.send(method, *arguments))
      end

      def handle_response(response)
        case response.code.to_i
          when 200...400
            response
          when 404
            raise(ResourceNotFound.new(response))
          when 400
            raise(ResourceInvalid.new(response))
          when 409
            raise(ResourceConflict.new(response))
          when 401...500
            raise(ClientError.new(response))
          when 500...600
            raise(ServerError.new(response))
          else
            raise(ConnectionError.new(response, "Unknown response code: #{response.code}"))
        end
      end

      def http
        unless @http
          @http             = Net::HTTP.new(@site.host, @site.port)
          @http.use_ssl     = @site.is_a?(URI::HTTPS)
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @http.use_ssl
        end

        @http
      end
  end
end
