require File.dirname(__FILE__) + '/abstract_unit'
require 'webrick'
require 'webrick/log'
require 'singleton'

module ClientTest
  class Person < ActionService::Struct
    member :firstnames, [:string]
    member :lastname,   :string

    def ==(other)
      firstnames == other.firstnames && lastname == other.lastname
    end
  end

  class API < ActionService::API::Base
    api_method :void
    api_method :normal,         :expects => [:int, :int], :returns => [:int]
    api_method :array_return,   :returns => [[Person]]
    api_method :struct_pass,    :expects => [[Person]], :returns => [:bool]
    api_method :client_container, :returns => [:int]
  end

  class NullLogOut
    def <<(*args); end
  end

  class Container < ActionController::Base
    service_api API

    attr :value_void
    attr :value_normal
    attr :value_array_return
    attr :value_struct_pass

    def initialize
      @session = @assigns = {}
      @value_void = nil
      @value_normal = nil
      @value_array_return = nil
      @value_struct_pass = nil
    end

    def void
      @value_void = @method_params
    end

    def normal
      @value_normal = @method_params
      5
    end

    def array_return
      person = Person.new
      person.firstnames = ["one", "two"]
      person.lastname = "last"
      @value_array_return = [person]
    end

    def struct_pass
      @value_struct_pass = @method_params
      true
    end

    def client_container
      50
    end

    def protocol_request(request)
      probe_request_protocol(request)
    end

    def dispatch_request(protocol_request)
      dispatch_service_request(protocol_request)
    end
  end

  class AbstractClientLet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(controller)
      @controller = controller
    end

    def get_instance(*args)
      self
    end

    def require_path_info?
      false
    end
  
    def do_GET(req, res)
      raise WEBrick::HTTPStatus::MethodNotAllowed, "GET request not allowed."
    end
  
    def do_POST(req, res)
      raise NotImplementedError
    end
  end

  class AbstractServer
    include ClientTest
    include Singleton
    attr :container
    def initialize
      @container = Container.new
      @clientlet = create_clientlet(@container)
      log = WEBrick::BasicLog.new(NullLogOut.new)
      @server = WEBrick::HTTPServer.new(:Port => server_port, :Logger => log, :AccessLog => log)
      @server.mount('/', @clientlet)
      @thr = Thread.new { @server.start }
      until @server.status == :Running; end
      at_exit { @server.stop; @thr.join }
    end
    
    protected
      def create_clientlet
        raise NotImplementedError
      end

      def server_port
        raise NotImplementedError
      end
  end
end
