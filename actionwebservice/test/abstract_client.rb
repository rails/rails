require File.dirname(__FILE__) + '/abstract_unit'
require 'webrick'
require 'webrick/log'
require 'singleton'

module ClientTest
  class Person < ActionWebService::Struct
    member :firstnames, [:string]
    member :lastname,   :string

    def ==(other)
      firstnames == other.firstnames && lastname == other.lastname
    end
  end
  
  class Inner < ActionWebService::Struct
    member :name, :string
  end
  
  class Outer < ActionWebService::Struct
    member :name, :string
    member :inner, Inner
  end

  class User < ActiveRecord::Base
  end
  
  module Accounting
    class User < ActiveRecord::Base
    end
  end
  
  class WithModel < ActionWebService::Struct
    member :user, User
    member :users, [User]
  end
  
  class WithMultiDimArray < ActionWebService::Struct
    member :pref, [[:string]]
  end

  class API < ActionWebService::API::Base
    api_method :void
    api_method :normal,               :expects => [:int, :int], :returns => [:int]
    api_method :array_return,         :returns => [[Person]]
    api_method :struct_pass,          :expects => [[Person]], :returns => [:bool]
    api_method :nil_struct_return,    :returns => [Person] 
    api_method :inner_nil,            :returns => [Outer]
    api_method :client_container,     :returns => [:int]
    api_method :named_parameters,     :expects => [{:key=>:string}, {:id=>:int}]
    api_method :thrower
    api_method :user_return,          :returns => [User]
    api_method :with_model_return,    :returns => [WithModel]
    api_method :scoped_model_return,  :returns => [Accounting::User]
    api_method :multi_dim_return,     :returns => [WithMultiDimArray]
  end
  
  class NullLogOut
    def <<(*args); end
  end

  class Container < ActionController::Base
    web_service_api API

    attr_accessor :value_void
    attr_accessor :value_normal
    attr_accessor :value_array_return
    attr_accessor :value_struct_pass
    attr_accessor :value_named_parameters

    def initialize
      @value_void = nil
      @value_normal = nil
      @value_array_return = nil
      @value_struct_pass = nil
      @value_named_parameters = nil
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
    
    def nil_struct_return
      nil
    end
    
    def inner_nil
      Outer.new :name => 'outer', :inner => nil
    end

    def client_container
      50
    end

    def named_parameters
      @value_named_parameters = @method_params
    end

    def thrower
      raise "Hi"
    end
    
    def user_return
      User.find(1)
    end
    
    def with_model_return
      WithModel.new :user => User.find(1), :users => User.find(:all)
    end
    
    def scoped_model_return
      Accounting::User.find(1)
    end
    
    def multi_dim_return
      WithMultiDimArray.new :pref => [%w{pref1 value1}, %w{pref2 value2}]
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
