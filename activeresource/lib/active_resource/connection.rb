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
  
  class ClientError < ConnectionError
  end

  class ServerError < ConnectionError
  end
  
  class ResourceNotFound < ClientError
  end

  class Connection
    attr_accessor :uri
    
    class << self
      def requests
        @@requests ||= []
      end
    end

    def initialize(site)
      @site = site
    end
    
    def get(path)
      Hash.create_from_xml(request(:get, path).body)
    end
    
    def delete(path)
      request(:delete, path)
    end
    
    def put(path, body)
      request(:put, path, body)
    end

    def post(path, body)
      request(:post, path, body)
    end
    
    private
      def request(method, *arguments)
        response = http.send(method, *arguments)

        case response.code.to_i
          when 200...300
            response
          when 404
            raise(ResourceNotFound.new(response))
          when 400...500
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