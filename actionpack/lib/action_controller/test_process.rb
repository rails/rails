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

  class TestRequest < Request #:nodoc:
    attr_accessor :query_parameters, :request_parameters, :session
    attr_accessor :host, :request_uri, :remote_addr

    def initialize(query_parameters = nil, request_parameters = nil, session = nil)
      @query_parameters   = query_parameters || {}
      @request_parameters = request_parameters || {}
      @session = session || TestSession.new({})
      @request_uri = ""
      super()
    end
    
    def cookies() {}.freeze end

    def action=(action_name)
      @query_parameters.update({ "action" => action_name })
    end
  end
  
  class TestResponse < Response #:nodoc:
  end

  class TestSession #:nodoc:
    def initialize(attributes)
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
  end
end