require File.dirname(__FILE__) + '/abstract_unit'
require 'xmlrpc/parser'
require 'xmlrpc/create'
require 'xmlrpc/config'

module XMLRPC
  class XmlRpcTestHelper
    include ParserWriterChooseMixin
  
    def create_request(methodName, *args)
      create().methodCall(methodName, *args)
    end

    def parse_response(response)
      parser().parseMethodResponse(response)
    end
  end
end

module ProtocolXmlRpcTest
  class Person < ActionService::Struct
    member :firstname, String
    member :lastname, String
    member :active, TrueClass
  end

  class API < ActionService::API::Base
    api_method :add,            :expects => [Integer, Integer], :returns => [Integer]
    api_method :hash_returner,  :returns => [Hash]
    api_method :array_returner, :returns => [[Integer]]
    api_method :something_hash, :expects => [Hash]
    api_method :struct_array_returner, :returns => [[Person]]
  
    default_api_method :default
  end

  class Service < ActionService::Base
    service_api API

    attr :result
    attr :hashvalue
    attr :default_args
  
    def initialize
      @result = nil
      @hashvalue = nil
      @default_args = nil
    end
  
    def add(a, b)
      @result = a + b
    end
  
    def something_hash(hash)
      @hashvalue = hash
    end
  
    def array_returner
      [1, 2, 3]
    end
    
    def hash_returner
      {'name' => 1, 'value' => 2}
    end

    def struct_array_returner
      person = Person.new
      person.firstname = "John"
      person.lastname = "Doe"
      person.active = true
      [person]
    end
  
    def default(*args)
      @default_args = args
      nil
    end
  end
  
  $service = Service.new
  
  class Container
    include ActionService::Container
    include ActionService::Protocol::Registry
    include ActionService::Protocol::Soap
    include ActionService::Protocol::XmlRpc
  
    def protocol_request(request)
      probe_request_protocol(request)
    end
  
    def dispatch_request(protocol_request)
      dispatch_service_request(protocol_request)
    end
  
    service :xmlrpc, $service
    service_dispatching_mode :delegated
  end
end

class TC_ProtocolXmlRpc < Test::Unit::TestCase
  def setup
    @helper = XMLRPC::XmlRpcTestHelper.new
    @container = ProtocolXmlRpcTest::Container.new
  end

  def test_xmlrpc_request_dispatching
    retval = do_xmlrpc_call('Add', 50, 30)
    assert(retval == [true, 80])
  end

  def test_array_returning
    retval = do_xmlrpc_call('ArrayReturner')
    assert(retval == [true, [1, 2, 3]])
  end

  def test_hash_returning
    retval = do_xmlrpc_call('HashReturner')
    assert(retval == [true, {'name' => 1, 'value' => 2}])
  end

  def test_struct_array_returning
    retval = do_xmlrpc_call('StructArrayReturner')
    assert(retval == [true, [{"firstname"=>"John", "lastname"=>"Doe", "active"=>true}]])
  end

  def test_hash_parameter
    retval = do_xmlrpc_call('SomethingHash', {'name' => 1, 'value' => 2})
    assert(retval == [true, true])
    assert($service.hashvalue == {'name' => 1, 'value' => 2})
  end

  def test_default_api_method
    retval = do_xmlrpc_call('SomeNonexistentMethod', 'test', [1, 2], {'name'=>'value'})
    assert(retval == [true, true])
    assert($service.default_args == ['test', [1, 2], {'name'=>'value'}])
  end

  def test_xmlrpc_introspection
    retval = do_xmlrpc_call('system.listMethods', 'test', [1, 2], {'name'=>'value'})
    assert(retval == [true,  ["Add", "ArrayReturner", "HashReturner", "SomethingHash", "StructArrayReturner"]])
  end

  private
    def do_xmlrpc_call(public_method_name, *args)
      service_name = 'xmlrpc'
      raw_request = @helper.create_request(public_method_name, *args)
      test_request = ActionController::TestRequest.new
      test_request.request_parameters['action'] = service_name
      test_request.env['REQUEST_METHOD'] = "POST"
      test_request.env['HTTP_CONTENTTYPE'] = 'text/xml'
      test_request.env['RAW_POST_DATA'] = raw_request
      protocol_request = @container.protocol_request(test_request)
      response = @container.dispatch_request(protocol_request)
      @helper.parse_response(response.raw_body)
    end
end
