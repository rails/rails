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

    def site=(site)
      @site = site.is_a?(URI) ? site : URI.parse(site)
    end

    def get(path)
      Hash.from_xml(request(:get, path, build_request_headers).body)
    end

    def delete(path)
      request(:delete, path, build_request_headers)
    end

    def put(path, body = '')
      request(:put, path, body, build_request_headers)
    end

    def post(path, body = '')
      request(:post, path, body, build_request_headers)
    end

    private
      def request(method, path, *arguments)
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}" if logger
        result = nil
        time = Benchmark.realtime { result = http.send(method, path, *arguments) }
        logger.info "--> #{result.code} #{result.message} (#{result.body.length}b %.2fs)" % time if logger
        handle_response(result)
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
      
      def build_request_headers
        authorization_header.update(self.class.default_header)
      end
      
      def authorization_header
        (@site.user || @site.password ? { 'Authorization' => 'Basic ' + ["#{@site.user}:#{ @site.password}"].pack('m').delete("\r\n") } : {})
      end

      def logger
        ActiveResource::Base.logger
      end
  end
end
