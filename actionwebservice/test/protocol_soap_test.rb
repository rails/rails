require File.dirname(__FILE__) + '/abstract_soap'

module ProtocolSoapTest
  class Person < ActionWebService::Struct
    member :id, Integer
    member :names, [String]
    member :lastname, String
    member :deleted, TrueClass

    def ==(other)
      id == other.id && names == other.names && lastname == other.lastname && deleted == other.deleted
    end
  end

  class EmptyAPI < ActionWebService::API::Base
  end

  class EmptyService < ActionWebService::Base
    web_service_api EmptyAPI
  end

  class API < ActionWebService::API::Base
    api_method :argument_passing, :expects => [{:int=>:int}, {:string=>:string}, {:array=>[:int]}], :returns => [:bool]
    api_method :array_returner, :returns => [[:int]]
    api_method :nil_returner
    api_method :struct_array_returner, :returns => [[Person]]
    api_method :exception_thrower
  
    default_api_method :default
  end

  class Service < ActionWebService::Base
    web_service_api API

    attr :int
    attr :string
    attr :array
    attr :values
    attr :person
    attr :default_args
  
    def initialize
      @int = 20
      @string = "wrong string value"
      @default_args = nil
    end
  
    def argument_passing(int, string, array)
      @int = int
      @string = string
      @array = array
      true
    end
  
    def array_returner
      @values = [1, 2, 3]
    end
  
    def nil_returner
      nil
    end
  
    def struct_array_returner
      @person = Person.new
      @person.id = 5
      @person.names = ["one", "two"]
      @person.lastname = "test"
      @person.deleted = false
      [@person]
    end
  
    def exception_thrower
      raise "Hi, I'm a SOAP error"
    end
  
    def default(*args)
      @default_args = args
      nil
    end 
  end

  class AbstractContainer < ActionController::Base
    wsdl_service_name 'Test'

    def dispatch_request(request)
      protocol_request = probe_request_protocol(request)
      dispatch_protocol_request(protocol_request)
    end
  end
  
  class DelegatedContainer < AbstractContainer
    web_service_dispatching_mode :delegated
    web_service :protocol_soap_service, Service.new
    web_service :empty_service, EmptyService.new
  end

  class DirectContainer < AbstractContainer
    web_service_api API
    web_service_dispatching_mode :direct

    attr :int
    attr :string
    attr :array
    attr :values
    attr :person
    attr :default_args
  
    def initialize
      @int = 20
      @string = "wrong string value"
      @default_args = nil
    end
  
    def argument_passing
      @int = @params['int']
      @string = @params['string']
      @array = @params['array']
      true
    end
  
    def array_returner
      @values = [1, 2, 3]
    end
  
    def nil_returner
      nil
    end
  
    def struct_array_returner
      @person = Person.new
      @person.id = 5
      @person.names = ["one", "two"]
      @person.lastname = "test"
      @person.deleted = false
      [@person]
    end
  
    def exception_thrower
      raise "Hi, I'm a SOAP error"
    end
  
    def default
      @default_args = @method_params
      nil
    end 
  end

  class EmptyContainer < AbstractContainer
    web_service_dispatching_mode :delegated
    web_service :empty_service, EmptyService.new
  end
end

class TC_ProtocolSoap < AbstractSoapTest
  def setup
    @delegated_container = ProtocolSoapTest::DelegatedContainer.new
    @direct_container = ProtocolSoapTest::DirectContainer.new
    @empty_container = ProtocolSoapTest::EmptyContainer.new
  end

  def test_argument_passing
    in_all_containers do
      assert(do_soap_call('ArgumentPassing', 5, "test string", [true, false]) == true)
      assert(service.int == 5)
      assert(service.string == "test string")
      assert(service.array == [true, false])
    end
  end

  def test_array_returner
    in_all_containers do
      assert(do_soap_call('ArrayReturner') == [1, 2, 3])
      assert(service.values == [1, 2, 3])
    end
  end

  def test_nil_returner
    in_all_containers do
      assert(do_soap_call('NilReturner') == nil)
    end
  end

  def test_struct_array_returner
    in_all_containers do
      assert(do_soap_call('StructArrayReturner') == [service.person])
    end
  end

  def test_nonexistent_method
    @container = @empty_container
    assert_raises(ActionWebService::Dispatcher::DispatcherError) do
      do_soap_call('NonexistentMethod')
    end
  end

  def test_exception_thrower
    in_all_containers do
      assert_raises(RuntimeError) do
        do_soap_call('ExceptionThrower')
      end
    end
  end

  def test_default_api_method
    in_all_containers do
      assert(do_soap_call('NonExistentMethodName', 50, false).nil?)
      assert(service.default_args == [50, false])
    end
  end

  def test_service_name_setting
    in_all_containers do
      assert(ProtocolSoapTest::DelegatedContainer.soap_mapper.custom_namespace == 'urn:Test')
    end
  end

  protected
    def service_name
      case
      when @container == @direct_container
        'api'
      when @container == @delegated_container
        'protocol_soap_service'
      when @container == @empty_container
        'empty_service'
      end
    end

    def service
      case
      when @container == @direct_container
        @container
      when @container == @delegated_container
        @container.web_service_object(:protocol_soap_service)
      when @container == @empty_container
        @container.web_service_object(:empty_service)
      end
    end

    def in_all_containers(&block)
      [@direct_container, @delegated_container].each do |container|
        @container = container
        block.call
      end
    end

    def do_soap_call(public_method_name, *args)
      super(public_method_name, *args) do |test_request, test_response|
        @container.dispatch_request(test_request)
      end
    end
end
