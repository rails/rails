require File.dirname(__FILE__) + '/abstract_unit'

module DispatcherTest
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
  end

  class API < ActionWebService::API::Base
    api_method :add, :expects => [:int, :int], :returns => [:int]
    api_method :interceptee
    api_method :struct_return, :returns => [[Node]]
    api_method :void
  end

  class DirectAPI < ActionWebService::API::Base
    api_method :add, :expects => [{:a=>:int}, {:b=>:int}], :returns => [:int]
    api_method :before_filtered
    api_method :after_filtered, :returns => [[:int]]
    api_method :struct_return, :returns => [[Node]]
    api_method :base_struct_return, :returns => [[Person]]
    api_method :thrower
    api_method :void
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
  end

  class BloggerAPI < ActionWebService::API::Base
    inflect_names false
    api_method :getCategories, :returns => [[:string]]
  end

  class MTService < ActionWebService::Base
    web_service_api MTAPI

    def getCategories
      ["mtCat1", "mtCat2"]
    end
  end

  class BloggerService < ActionWebService::Base
    web_service_api BloggerAPI

    def getCategories
      ["bloggerCat1", "bloggerCat2"]
    end
  end

  class AbstractController < ActionController::Base
    def generate_wsdl
      to_wsdl
    end
  end
 
  class DelegatedController < AbstractController
    web_service_dispatching_mode :delegated
  
    web_service(:test_service) { @service ||= Service.new; @service }
  end

  class LayeredController < AbstractController
    web_service_dispatching_mode :layered

    web_service(:mt) { @mt_service ||= MTService.new; @mt_service }
    web_service(:blogger) { @blogger_service ||= BloggerService.new; @blogger_service }
  end
 
  class DirectController < AbstractController
    web_service_api DirectAPI
    web_service_dispatching_mode :direct

    before_filter :alwaysfail, :only => [:before_filtered]
    after_filter :alwaysok, :only => [:after_filtered]

    attr :added
    attr :before_filter_called
    attr :before_filter_target_called
    attr :after_filter_called
    attr :after_filter_target_called
    attr :void_called

    def initialize
      @before_filter_called = false
      @before_filter_target_called = false
      @after_filter_called = false
      @after_filter_target_called = false
      @void_called = false
    end
  
    def add
      @added = @params['a'] + @params['b']
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

    def base_struct_return
      p1 = Person.new('id' => 1, 'name' => 'person1')
      p2 = Person.new('id' => 2, 'name' => 'person2')
      [p1, p2]
    end
    
    def void
      @void_called = @method_params
    end

    protected
      def alwaysfail
        @before_filter_called = true
        false
      end

      def alwaysok
        @after_filter_called = true
      end
  end

  class VirtualController < AbstractController
    web_service_api VirtualAPI

    def fallback
      "fallback!"
    end
  end
end

module DispatcherCommonTests
  def test_direct_dispatching
    assert_equal(70, do_method_call(@direct_controller, 'Add', 20, 50))
    assert_equal(70, @direct_controller.added)
    assert(@direct_controller.void_called == false)
    case @encoder
    when WS::Encoding::SoapRpcEncoding
      assert(do_method_call(@direct_controller, 'Void', 3, 4, 5).nil?)
    when WS::Encoding::XmlRpcEncoding
      assert(do_method_call(@direct_controller, 'Void', 3, 4, 5) == true)
    end
    assert(@direct_controller.void_called == [])
    result = do_method_call(@direct_controller, 'BaseStructReturn')
    case @encoder
    when WS::Encoding::SoapRpcEncoding
      assert(result[0].is_a?(DispatcherTest::Person))
      assert(result[1].is_a?(DispatcherTest::Person))
    when WS::Encoding::XmlRpcEncoding
      assert(result[0].is_a?(Hash))
      assert(result[1].is_a?(Hash))
    end
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
    case @encoder
    when WS::Encoding::SoapRpcEncoding
      assert(do_method_call(@delegated_controller, 'Void', 3, 4, 5).nil?)
    when WS::Encoding::XmlRpcEncoding
      assert(do_method_call(@delegated_controller, 'Void', 3, 4, 5) == true)
    end
    assert(service.void_called == [])
  end

  def test_garbage_request
    [@direct_controller, @delegated_controller].each do |controller|
      controller.class.web_service_exception_reporting = true
      send_garbage_request = lambda do
        request = create_ap_request(controller, 'invalid request body', 'xxx')
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
      case @encoder
      when WS::Encoding::SoapRpcEncoding
        assert(result[0].is_a?(DispatcherTest::Node))
        assert(result[1].is_a?(DispatcherTest::Node))
        assert_equal('node1', result[0].name)
        assert_equal('node2', result[1].name)
      when WS::Encoding::XmlRpcEncoding
        assert(result[0].is_a?(Hash))
        assert(result[1].is_a?(Hash))
        assert_equal('node1', result[0]['name'])
        assert_equal('node2', result[1]['name'])
      end
    end
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

    def do_method_call(container, public_method_name, *params)
      mode = container.web_service_dispatching_mode
      case mode
      when :direct
        api = container.class.web_service_api
      when :delegated
        api = container.web_service_object(service_name(container)).class.web_service_api
      when :layered
        service_name = nil
        if public_method_name =~ /^([^\.]+)\.(.*)$/
          service_name = $1
        end
        api = container.web_service_object(service_name.to_sym).class.web_service_api
      end
      info = api.api_methods[method_name] || {}
      params = params.dup
      ((info[:expects] || []) + (info[:returns] || [])).each do |spec|
        @marshaler.register_type(spec)
      end
      expects = info[:expects]
      (0..(params.length-1)).each do |i|
        type_binding = @marshaler.register_type(expects ? expects[i] : params[i].class)
        info = WS::ParamInfo.create(expects ? expects[i] : params[i].class, type_binding, i)
        params[i] = @marshaler.marshal(WS::Param.new(params[i], info))
      end
      body = @encoder.encode_rpc_call(public_method_name, params)
      # puts body
      ap_request = create_ap_request(container, body, public_method_name, *params)
      ap_response = ActionController::TestResponse.new
      container.process(ap_request, ap_response)
      # puts ap_response.body
      public_method_name, return_value = @encoder.decode_rpc_response(ap_response.body)
      @marshaler.unmarshal(return_value).value
    end
end
