require File.dirname(__FILE__) + '/abstract_soap'
require 'wsdl/parser'

module RouterActionControllerTest
  class API < ActionService::API::Base
    api_method :add, :expects => [:int, :int], :returns => [:int]
  end

  class Service < ActionService::Base
    service_api API

    attr :added
  
    def add(a, b)
      @added = a + b
    end
  end
  
  class DelegatedController < ActionController::Base
    service_dispatching_mode :delegated
  
    service(:test_service) { @service ||= Service.new; @service }
  end

  class DirectAPI < ActionService::API::Base
    api_method :add, :expects => [{:a=>:int}, {:b=>:int}], :returns => [:int]
    api_method :before_filtered
    api_method :after_filtered, :returns => [:int]
    api_method :thrower
  end
  
  class DirectController < ActionController::Base
    service_api DirectAPI
    service_dispatching_mode :direct

    before_filter :alwaysfail, :only => [:before_filtered]
    after_filter :alwaysok, :only => [:after_filtered]

    attr :added
    attr :before_filter_called
    attr :before_filter_target_called
    attr :after_filter_called
    attr :after_filter_target_called

    def initialize
      @before_filter_called = false
      @before_filter_target_called = false
      @after_filter_called = false
      @after_filter_target_called = false
    end
  
    def add
      @added = @params['a'] + @params['b']
    end

    def before_filtered
      @before_filter_target_called = true
    end

    def after_filtered
      @after_filter_target_called = true
      5
    end

    def thrower
      raise "Hi, I'm a SOAP exception"
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
end

class TC_RouterActionController < AbstractSoapTest
  def test_direct_routing
    @container = RouterActionControllerTest::DirectController.new
    assert(do_soap_call('Add', 20, 50) == 70)
    assert(@container.added == 70)
  end

  def test_direct_entrypoint
    @container = RouterActionControllerTest::DirectController.new
    assert(@container.respond_to?(:api))
  end

  def test_direct_filtering
    @container = RouterActionControllerTest::DirectController.new
    assert(@container.before_filter_called == false)
    assert(@container.before_filter_target_called == false)
    assert(do_soap_call('BeforeFiltered').nil?)
    assert(@container.before_filter_called == true)
    assert(@container.before_filter_target_called == false)
    assert(@container.after_filter_called == false)
    assert(@container.after_filter_target_called == false)
    assert(do_soap_call('AfterFiltered') == 5)
    assert(@container.after_filter_called == true)
    assert(@container.after_filter_target_called == true)
  end

  def test_delegated_routing
    @container = RouterActionControllerTest::DelegatedController.new
    assert(do_soap_call('Add', 50, 80) == 130)
    assert(service.added == 130)
  end

  def test_exception_marshaling
    @container = RouterActionControllerTest::DirectController.new
    result = do_soap_call('Thrower')
    exception = result.detail
    assert(exception.cause.is_a?(RuntimeError))
    assert_equal("Hi, I'm a SOAP exception", exception.cause.message)
    @container.service_exception_reporting = false
    assert_raises(SoapTestError) do
      do_soap_call('Thrower')
    end
  end

  protected
    def service_name
      @container.is_a?(RouterActionControllerTest::DelegatedController) ? 'test_service' : 'api'
    end

    def service
      @container.service_object(:test_service)
    end

    def do_soap_call(public_method_name, *args)
      super(public_method_name, *args) do |test_request, test_response|
        response = @container.process(test_request, test_response)
      end
    end
end
