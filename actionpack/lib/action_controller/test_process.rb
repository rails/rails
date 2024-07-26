module ActionController #:nodoc:
  class Base
    # Process a test request called with a +TestRequest+ object.
    def self.process_test(request)
      new.process_test(request)
    end
  
    def process_test(request) #:nodoc:
      process(request, TestResponse.new)
    end
  end

  class TestRequest < AbstractRequest #:nodoc:
    attr_writer   :cookies
    attr_accessor :query_parameters, :request_parameters, :session, :env
    attr_accessor :host, :path, :request_uri, :remote_addr

    def initialize(query_parameters = nil, request_parameters = nil, session = nil)
      @query_parameters   = query_parameters || {}
      @request_parameters = request_parameters || {}
      @session            = session || TestSession.new
      
      initialize_containers
      initialize_default_values

      super()
    end

    def reset_session
      @session = {}
    end    

    def cookies
      @cookies.freeze
    end

    def action=(action_name)
      @query_parameters.update({ "action" => action_name })
      @parameters = nil
    end

    private
      def initialize_containers
        @env, @cookies = {}, {}
      end
    
      def initialize_default_values
        @host               = "test.host"
        @request_uri        = "/"
        @remote_addr        = "127.0.0.1"        
        @env["SERVER_PORT"] = 80
      end
  end
  
  class TestResponse < AbstractResponse #:nodoc:
  end

  class TestSession #:nodoc:
    def initialize(attributes = {})
      @attributes = attributes
    end

    def [](key)
      @attributes[key]
    end

    def []=(key, value)
      @attributes[key] = value
    end
    
    def update() end
    def close() end
    def delete() @attributes = {} end
  end
end