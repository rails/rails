require File.dirname(__FILE__) + '/abstract_unit'
require 'stringio'

class ActionController::Base; def rescue_action(e) raise e end; end

module DispatcherTest
  Utf8String = "One World Caf\303\251"
  WsdlNamespace = 'http://rubyonrails.com/some/namespace'

  class Node < ActiveRecord::Base
    def initialize(*args)
      super(*args)
      @new_record = false
    end

    class << self
      def name
        "DispatcherTest::Node"
      end

      def columns(*args)
        [
          ActiveRecord::ConnectionAdapters::Column.new('id', 0, 'int'),
          ActiveRecord::ConnectionAdapters::Column.new('name', nil, 'string'),
          ActiveRecord::ConnectionAdapters::Column.new('description', nil, 'string'),
        ]
      end

      def connection
        self
      end
    end
  end

  class Person < ActionWebService::Struct
    member :id, :int
    member :name, :string

    def ==(other)
      self.id == other.id && self.name == other.name
    end
  end

  class API < ActionWebService::API::Base
    api_method :add, :expects => [:int, :int], :returns => [:int]
    api_method :interceptee
    api_method :struct_return, :returns => [[Node]]
    api_method :void
  end

  class DirectAPI < ActionWebService::API::Base
    api_method :add, :expects => [{:a=>:int}, {:b=>:int}], :returns => [:int]
    api_method :add2, :expects => [{:a=>:int}, {:b=>:int}], :returns => [:int]
    api_method :before_filtered
    api_method :after_filtered, :returns => [[:int]]
    api_method :struct_return, :returns => [[Node]]
    api_method :struct_pass, :expects => [{:person => Person}]
    api_method :base_struct_return, :returns => [[Person]]
    api_method :hash_struct_return, :returns => [[Person]]
    api_method :thrower
    api_method :void
    api_method :test_utf8, :returns => [:string]
    api_method :hex, :expects => [:base64], :returns => [:string]
    api_method :unhex, :expects => [:string], :returns => [:base64]
    api_method :time, :expects => [:time], :returns => [:time]
  end

  class VirtualAPI < ActionWebService::API::Base
    default_api_method :fallback
  end
 
  class Service < ActionWebService::Base
    web_service_api API

    before_invocation :do_intercept, :only => [:interceptee]

    attr :added
    attr :intercepted
    attr :void_called

    def initialize
      @void_called = false
    end

    def add(a, b)
      @added = a + b
    end

    def interceptee
      @intercepted = false
    end

    def struct_return
      n1 = Node.new('id' => 1, 'name' => 'node1', 'description' => 'Node 1')
      n2 = Node.new('id' => 2, 'name' => 'node2', 'description' => 'Node 2')
      [n1, n2]
    end

    def void(*args)
      @void_called = args
    end

    def do_intercept(name, args)
      [false, "permission denied"]
    end
  end

  class MTAPI < ActionWebService::API::Base
    inflect_names false
    api_method :getCategories, :returns => [[:string]]
    api_method :bool, :returns => [:bool]
    api_method :alwaysFail
    api_method :person, :returns => [Person]
  end

  class BloggerAPI < ActionWebService::API::Base
    inflect_names false
    api_method :getCategories, :returns => [[:string]]
    api_method :str, :expects => [:int], :returns => [:string]
    api_method :alwaysFail
  end

  class MTService < ActionWebService::Base
    web_service_api MTAPI

    def getCategories
      ["mtCat1", "mtCat2"]
    end
    
    def bool
      'y'
    end
    
    def alwaysFail
      raise "MT AlwaysFail"
    end
    
    def person
      Person.new('id' => 1, 'name' => 'person1')
    end
  end

  class BloggerService < ActionWebService::Base
    web_service_api BloggerAPI

    def getCategories
      ["bloggerCat1", "bloggerCat2"]
    end

    def str(int)
      unless int.is_a?(Integer)
        raise "Not an integer!"
      end
      500 + int
    end

    def alwaysFail
      raise "Blogger AlwaysFail"
    end
  end

  class AbstractController < ActionController::Base
    def generate_wsdl
      self.request ||= ::ActionController::TestRequest.new
      to_wsdl
    end
  end
 
  class DelegatedController < AbstractController
    web_service_dispatching_mode :delegated
    wsdl_namespace WsdlNamespace
  
    web_service(:test_service) { @service ||= Service.new; @service }
  end

  class LayeredController < AbstractController
    web_service_dispatching_mode :layered
    wsdl_namespace WsdlNamespace

    web_service(:mt) { @mt_service ||= MTService.new; @mt_service }
    web_service(:blogger) { @blogger_service ||= BloggerService.new; @blogger_service }
  end
 
  class DirectController < AbstractController
    web_service_api DirectAPI
    web_service_dispatching_mode :direct
    wsdl_namespace WsdlNamespace

    before_invocation :alwaysfail, :only => [:before_filtered]
    after_invocation :alwaysok, :only => [:after_filtered]

    attr :added
    attr :added2
    attr :before_filter_called
    attr :before_filter_target_called
    attr :after_filter_called
    attr :after_filter_target_called
    attr :void_called
    attr :struct_pass_value

    def initialize
      @before_filter_called = false
      @before_filter_target_called = false
      @after_filter_called = false
      @after_filter_target_called = false
      @void_called = false
      @struct_pass_value = false
    end
  
    def add
      @added = params['a'] + params['b']
    end

    def add2(a, b)
      @added2 = a + b
    end

    def before_filtered
      @before_filter_target_called = true
    end

    def after_filtered
      @after_filter_target_called = true
      [5, 6, 7]
    end

    def thrower
      raise "Hi, I'm an exception"
    end

    def struct_return
      n1 = Node.new('id' => 1, 'name' => 'node1', 'description' => 'Node 1')
      n2 = Node.new('id' => 2, 'name' => 'node2', 'description' => 'Node 2')
      [n1, n2]
    end

    def struct_pass(person)
      @struct_pass_value = person
    end

    def base_struct_return
      p1 = Person.new('id' => 1, 'name' => 'person1')
      p2 = Person.new('id' => 2, 'name' => 'person2')
      [p1, p2]
    end

    def hash_struct_return
      p1 = { :id => '1', 'name' => 'test' }
      p2 = { 'id' => '2', :name => 'person2' }
      [p1, p2]
    end
    
    def void
      @void_called = @method_params
    end

    def test_utf8
      Utf8String
    end

    def hex(s)
      return s.unpack("H*")[0]
    end

    def unhex(s)
      return [s].pack("H*")
    end

    def time(t)
      t
    end

    protected
      def alwaysfail(method_name, params)
        @before_filter_called = true
        false
      end

      def alwaysok(method_name, params, return_value)
        @after_filter_called = true
      end
  end

  class VirtualController < AbstractController
    web_service_api VirtualAPI
    wsdl_namespace WsdlNamespace

    def fallback
      "fallback!"
    end
  end
end

module DispatcherCommonTests
  def test_direct_dispatching
    assert_equal(70, do_method_call(@direct_controller, 'Add', 20, 50))
    assert_equal(70, @direct_controller.added)
    assert_equal(50, do_method_call(@direct_controller, 'Add2', 25, 25))
    assert_equal(50, @direct_controller.added2)
    assert(@direct_controller.void_called == false)
    assert(do_method_call(@direct_controller, 'Void', 3, 4, 5).nil?)
    assert(@direct_controller.void_called == [])
    result = do_method_call(@direct_controller, 'BaseStructReturn')
    assert(result[0].is_a?(DispatcherTest::Person))
    assert(result[1].is_a?(DispatcherTest::Person))
    assert_equal("cafe", do_method_call(@direct_controller, 'Hex', "\xca\xfe"))
    assert_equal("\xca\xfe", do_method_call(@direct_controller, 'Unhex', "cafe"))
    time = Time.gm(1998, "Feb", 02, 15, 12, 01)
    assert_equal(time, do_method_call(@direct_controller, 'Time', time))
  end

  def test_direct_entrypoint
    assert(@direct_controller.respond_to?(:api))
  end
  
  def test_virtual_dispatching
    assert_equal("fallback!", do_method_call(@virtual_controller, 'VirtualOne'))
    assert_equal("fallback!", do_method_call(@virtual_controller, 'VirtualTwo'))
  end

  def test_direct_filtering
    assert_equal(false, @direct_controller.before_filter_called)
    assert_equal(false, @direct_controller.before_filter_target_called)
    do_method_call(@direct_controller, 'BeforeFiltered')
    assert_equal(true, @direct_controller.before_filter_called)
    assert_equal(false, @direct_controller.before_filter_target_called)
    assert_equal(false, @direct_controller.after_filter_called)
    assert_equal(false, @direct_controller.after_filter_target_called)
    assert_equal([5, 6, 7], do_method_call(@direct_controller, 'AfterFiltered'))
    assert_equal(true, @direct_controller.after_filter_called)
    assert_equal(true, @direct_controller.after_filter_target_called)
  end

  def test_delegated_dispatching
    assert_equal(130, do_method_call(@delegated_controller, 'Add', 50, 80))
    service = @delegated_controller.web_service_object(:test_service)
    assert_equal(130, service.added)
    @delegated_controller.web_service_exception_reporting = true
    assert(service.intercepted.nil?)
    result = do_method_call(@delegated_controller, 'Interceptee')
    assert(service.intercepted.nil?)
    assert(is_exception?(result))
    assert_match(/permission denied/, exception_message(result))
    result = do_method_call(@delegated_controller, 'NonExistentMethod')
    assert(is_exception?(result))
    assert_match(/NonExistentMethod/, exception_message(result))
    assert(service.void_called == false)
    assert(do_method_call(@delegated_controller, 'Void', 3, 4, 5).nil?)
    assert(service.void_called == [])
  end

  def test_garbage_request
    [@direct_controller, @delegated_controller].each do |controller|
      controller.class.web_service_exception_reporting = true
      send_garbage_request = lambda do
        service_name = service_name(controller)
        request = protocol.encode_action_pack_request(service_name, 'broken, method, name!', 'broken request body', :request_class => ActionController::TestRequest)
        response = ActionController::TestResponse.new
        controller.process(request, response)
        # puts response.body
        assert(response.headers['Status'] =~ /^500/)
      end
      send_garbage_request.call
      controller.class.web_service_exception_reporting = false
      send_garbage_request.call
    end
  end

  def test_exception_marshaling
    @direct_controller.web_service_exception_reporting = true
    result = do_method_call(@direct_controller, 'Thrower')
    assert(is_exception?(result))
    assert_equal("Hi, I'm an exception", exception_message(result))
    @direct_controller.web_service_exception_reporting = false
    result = do_method_call(@direct_controller, 'Thrower')
    assert(exception_message(result) != "Hi, I'm an exception")
  end

  def test_ar_struct_return
    [@direct_controller, @delegated_controller].each do |controller|
      result = do_method_call(controller, 'StructReturn')
      assert(result[0].is_a?(DispatcherTest::Node))
      assert(result[1].is_a?(DispatcherTest::Node))
      assert_equal('node1', result[0].name)
      assert_equal('node2', result[1].name)
    end
  end

  def test_casting
    assert_equal 70, do_method_call(@direct_controller, 'Add', "50", "20")
    assert_equal false, @direct_controller.struct_pass_value
    person = DispatcherTest::Person.new(:id => 1, :name => 'test') 
    result = do_method_call(@direct_controller, 'StructPass', person)
    assert(nil == result || true == result)
    assert_equal person, @direct_controller.struct_pass_value
    assert !person.equal?(@direct_controller.struct_pass_value)
    result = do_method_call(@direct_controller, 'StructPass', {'id' => '1', 'name' => 'test'})
    case
    when soap?
      assert_equal(person, @direct_controller.struct_pass_value)
      assert !person.equal?(@direct_controller.struct_pass_value)
    when xmlrpc?
      assert_equal(person, @direct_controller.struct_pass_value)
      assert !person.equal?(@direct_controller.struct_pass_value)
    end
    assert_equal person, do_method_call(@direct_controller, 'HashStructReturn')[0]
    result = do_method_call(@direct_controller, 'StructPass', {'id' => '1', 'name' => 'test', 'nonexistent_attribute' => 'value'})
    case
    when soap?
      assert_equal(person, @direct_controller.struct_pass_value)
      assert !person.equal?(@direct_controller.struct_pass_value)
    when xmlrpc?
      assert_equal(person, @direct_controller.struct_pass_value)
      assert !person.equal?(@direct_controller.struct_pass_value)
    end
  end

  def test_logging
    buf = ""
    ActionController::Base.logger = Logger.new(StringIO.new(buf))
    test_casting
    test_garbage_request
    test_exception_marshaling
    ActionController::Base.logger = nil
    assert_match /Web Service Response/, buf
    assert_match /Web Service Request/, buf
  end

  protected
    def service_name(container)
      raise NotImplementedError
    end

    def exception_message(obj)
      raise NotImplementedError
    end

    def is_exception?(obj)
      raise NotImplementedError
    end

    def protocol
      @protocol
    end

    def soap?
      protocol.is_a? ActionWebService::Protocol::Soap::SoapProtocol
    end

    def xmlrpc?
      protocol.is_a? ActionWebService::Protocol::XmlRpc::XmlRpcProtocol
    end

    def do_method_call(container, public_method_name, *params)
      request_env = {}
      mode = container.web_service_dispatching_mode
      case mode
      when :direct
        service_name = service_name(container)
        api = container.class.web_service_api
        method = api.public_api_method_instance(public_method_name)
      when :delegated
        service_name = service_name(container)
        api = container.web_service_object(service_name).class.web_service_api
        method = api.public_api_method_instance(public_method_name)
      when :layered
        service_name = nil
        real_method_name = nil
        if public_method_name =~ /^([^\.]+)\.(.*)$/
          service_name = $1
          real_method_name = $2
        end
        if soap?
          public_method_name = real_method_name
          request_env['HTTP_SOAPACTION'] = "/soap/#{service_name}/#{real_method_name}"
        end
        api = container.web_service_object(service_name.to_sym).class.web_service_api rescue nil
        method = api.public_api_method_instance(real_method_name) rescue nil
        service_name = self.service_name(container)
      end
      protocol.register_api(api)
      virtual = false
      unless method
        virtual = true
        method ||= ActionWebService::API::Method.new(public_method_name.underscore.to_sym, public_method_name, nil, nil)
      end
      body = protocol.encode_request(public_method_name, params.dup, method.expects)
      # puts body
      ap_request = protocol.encode_action_pack_request(service_name, public_method_name, body, :request_class => ActionController::TestRequest)
      ap_request.env.update(request_env)
      ap_response = ActionController::TestResponse.new
      container.process(ap_request, ap_response)
      # puts ap_response.body
      @response_body = ap_response.body
      public_method_name, return_value = protocol.decode_response(ap_response.body)
      unless is_exception?(return_value) || virtual
        return_value = method.cast_returns(return_value)
      end
      if soap?
        # http://dev.rubyonrails.com/changeset/920
        assert_match(/Response$/, public_method_name) unless public_method_name == "fault"
      end
      return_value
    end
end
