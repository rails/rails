$:.unshift(File.dirname(__FILE__) + '/apis')
require File.dirname(__FILE__) + '/abstract_dispatcher'
require 'wsdl/parser'

class ActionController::Base
  class << self
    alias :inherited_without_name_error :inherited
    def inherited(child)
      begin
        inherited_without_name_error(child)
      rescue NameError => e
      end
    end
  end
end

class AutoLoadController < ActionController::Base; end
class FailingAutoLoadController < ActionController::Base; end
class BrokenAutoLoadController < ActionController::Base; end

class TC_DispatcherActionControllerSoap < Test::Unit::TestCase
  include DispatcherTest
  include DispatcherCommonTests

  def setup
    @direct_controller = DirectController.new
    @delegated_controller = DelegatedController.new
    @virtual_controller = VirtualController.new
    @layered_controller = LayeredController.new
    @protocol = ActionWebService::Protocol::Soap::SoapProtocol.create(@direct_controller)
  end

  def test_wsdl_generation
    ensure_valid_wsdl_generation DelegatedController.new, DispatcherTest::WsdlNamespace
    ensure_valid_wsdl_generation DirectController.new, DispatcherTest::WsdlNamespace
  end

  def test_wsdl_action
    delegated_types = ensure_valid_wsdl_action DelegatedController.new
    delegated_names = delegated_types.map{|x| x.name.name}
    assert(delegated_names.include?('DispatcherTest..NodeArray'))
    assert(delegated_names.include?('DispatcherTest..Node'))
    direct_types = ensure_valid_wsdl_action DirectController.new
    direct_names = direct_types.map{|x| x.name.name}
    assert(direct_names.include?('DispatcherTest..NodeArray'))
    assert(direct_names.include?('DispatcherTest..Node'))
    assert(direct_names.include?('IntegerArray'))
  end

  def test_autoloading
    assert(!AutoLoadController.web_service_api.nil?)
    assert(AutoLoadController.web_service_api.has_public_api_method?('Void'))
    assert(FailingAutoLoadController.web_service_api.nil?)
    assert_raises(MissingSourceFile) do
      FailingAutoLoadController.require_web_service_api :blah
    end
    assert_raises(ArgumentError) do
      FailingAutoLoadController.require_web_service_api 50.0
    end
    assert(BrokenAutoLoadController.web_service_api.nil?)
  end

  def test_layered_dispatching
    mt_cats = do_method_call(@layered_controller, 'mt.getCategories')
    assert_equal(["mtCat1", "mtCat2"], mt_cats)
    blogger_cats = do_method_call(@layered_controller, 'blogger.getCategories')
    assert_equal(["bloggerCat1", "bloggerCat2"], blogger_cats)
  end

  def test_utf8
    @direct_controller.web_service_exception_reporting = true
    $KCODE = 'u'
    assert_equal(Utf8String, do_method_call(@direct_controller, 'TestUtf8'))
    retval = SOAP::Processor.unmarshal(@response_body).body.response
    assert retval.is_a?(SOAP::SOAPString)

    # If $KCODE is not set to UTF-8, any strings with non-ASCII UTF-8 data
    # will be sent back as base64 by SOAP4R. By the time we get it here though,
    # it will be decoded back into a string. So lets read the base64 value
    # from the message body directly.
    $KCODE = 'NONE'
    do_method_call(@direct_controller, 'TestUtf8')
    retval = SOAP::Processor.unmarshal(@response_body).body.response
    assert retval.is_a?(SOAP::SOAPBase64)
    assert_equal "T25lIFdvcmxkIENhZsOp", retval.data.to_s
  end

  protected
    def exception_message(soap_fault_exception)
      soap_fault_exception.detail.cause.message
    end

    def is_exception?(obj)
      obj.respond_to?(:detail) && obj.detail.respond_to?(:cause) && \
      obj.detail.cause.is_a?(Exception)
    end

    def service_name(container)
      container.is_a?(DelegatedController) ? 'test_service' : 'api'
    end

    def ensure_valid_wsdl_generation(controller, expected_namespace)
      wsdl = controller.generate_wsdl
      ensure_valid_wsdl(controller, wsdl, expected_namespace)
    end

    def ensure_valid_wsdl(controller, wsdl, expected_namespace)
      definitions = WSDL::Parser.new.parse(wsdl)
      assert(definitions.is_a?(WSDL::Definitions))
      definitions.bindings.each do |binding|
        assert(binding.name.name.index(':').nil?)
      end
      definitions.services.each do |service|
        service.ports.each do |port|
          assert(port.name.name.index(':').nil?)
        end
      end
      types = definitions.collect_complextypes.map{|x| x.name}
      types.each do |type|
        assert(type.namespace == expected_namespace)
      end
      location = definitions.services[0].ports[0].soap_address.location
      if controller.is_a?(DelegatedController)
        assert_match %r{http://test.host/dispatcher_test/delegated/test_service$}, location
      elsif controller.is_a?(DirectController)
        assert_match %r{http://test.host/dispatcher_test/direct/api$}, location
      end
      definitions.collect_complextypes
    end

    def ensure_valid_wsdl_action(controller)
      test_request = ActionController::TestRequest.new({ 'action' => 'wsdl' })
      test_response = ActionController::TestResponse.new
      wsdl = controller.process(test_request, test_response).body
      ensure_valid_wsdl(controller, wsdl, DispatcherTest::WsdlNamespace)
    end
end
