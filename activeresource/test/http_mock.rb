require 'active_resource/connection'

module ActiveResource
  class HttpMock
    class Responder
      def initialize(responses)
        @responses = responses
      end
      
      for method in [ :post, :put, :get, :delete ]
        module_eval <<-EOE
          def #{method}(path, body = nil, status = 200, headers = {})
            @responses[Request.new(:#{method}, path, nil)] = Response.new(body || {}, status, headers)
          end
        EOE
      end
    end

    class << self
      def requests
        @@requests ||= []
      end

      def responses
        @@responses ||= {}
      end

      def respond_to(pairs = {})
        reset!
        pairs.each do |(path, response)|
          responses[path] = response
        end
        yield Responder.new(responses) if block_given?
      end

      def reset!
        requests.clear
        responses.clear
      end
    end

    for method in [ :post, :put, :get, :delete ]
      module_eval <<-EOE
        def #{method}(*arguments)
          request = ActiveResource::Request.new(:#{method}, *arguments)
          self.class.requests << request
          self.class.responses[request] || raise("No response recorded for: \#{request}")
        end
      EOE
    end
    
    def initialize(site)
      @site = site
    end
  end

  class Request
    attr_accessor :path, :method, :body
    
    def initialize(method, path, body = nil, headers = nil)
      @method, @path, @body = method, path, body
    end

    def ==(other_request)
      other_request.hash == hash
    end
    
    def eql?(other_request)
      self == other_request
    end
    
    def to_s
      "<#{method.to_s.upcase}: #{path} (#{body})>"
    end
    
    def hash
      "#{path}#{method}".hash
    end
  end
  
  class Response
    attr_accessor :body, :code, :headers
    
    def initialize(body, code = 200, headers = nil)
      @body, @code, @headers = body, code, headers
    end
    
    def success?
      (200..299).include?(code)
    end

    def [](key)
      headers[key]
    end
    
    def []=(key, value)
      headers[key] = value
    end

  end

  class Connection
    private
      silence_warnings do
        def http
          @http ||= HttpMock.new(@site)
        end
      end
  end
end
