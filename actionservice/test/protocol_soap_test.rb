require File.dirname(__FILE__) + '/abstract_soap'

module ProtocolSoapTest
  class Person < ActionService::Struct
    member :id, Integer
    member :names, [String]
    member :lastname, String
    member :deleted, TrueClass

    def ==(other)
      id == other.id && names == other.names && lastname == other.lastname && deleted == other.deleted
    end
  end

  class API < ActionService::API::Base
    api_method :argument_passing, :expects => [{:int=>:int}, {:string=>:string}, {:array=>[:int]}], :returns => [:bool]
    api_method :array_returner, :returns => [[:int]]
    api_method :nil_returner
    api_method :struct_array_returner, :returns => [[Person]]
    api_method :exception_thrower
  
    default_api_method :default
  end

  class Service < ActionService::Base
    service_api API

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

  class AbstractContainer
    include ActionService::API
    include ActionService::Container
    include ActionService::Protocol::Registry
    include ActionService::Protocol::Soap

    wsdl_service_name 'Test'

    def protocol_request(request)
      probe_request_protocol(request)
    end
  
    def dispatch_request(protocol_request)
      dispatch_service_request(protocol_request)
    end
  end
  
  class DelegatedContainer < AbstractContainer
    service_dispatching_mode :delegated
    service :protocol_soap_service, Service.new
  end

  class DirectContainer < AbstractContainer
    service_api API
    service_dispatching_mode :direct

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
end

class TC_ProtocolSoap < AbstractSoapTest
  def setup
    @delegated_container = ProtocolSoapTest::DelegatedContainer.new
    @direct_container = ProtocolSoapTest::DirectContainer.new
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
      @container == @direct_container ? 'api' : 'protocol_soap_service'
    end

    def service
      @container == @direct_container ? @container : @container.service_object(:protocol_soap_service)
    end

    def in_all_containers(&block)
      [@direct_container].each do |container|
        @container = container
        block.call
      end
    end

    def do_soap_call(public_method_name, *args)
      super(public_method_name, *args) do |test_request, test_response|
        protocol_request = @container.protocol_request(test_request)
        @container.dispatch_request(protocol_request)
      end
    end
end
