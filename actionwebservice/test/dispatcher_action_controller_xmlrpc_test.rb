require File.dirname(__FILE__) + '/abstract_dispatcher'

class TC_DispatcherActionControllerXmlRpc < Test::Unit::TestCase
  include DispatcherTest
  include DispatcherCommonTests

  def setup
    @protocol = ActionWebService::Protocol::XmlRpc::XmlRpcProtocol.new
    @encoder = WS::Encoding::XmlRpcEncoding.new
    @marshaler = WS::Marshaling::XmlRpcMarshaler.new
    @direct_controller = DirectController.new
    @delegated_controller = DelegatedController.new
    @layered_controller = LayeredController.new
    @virtual_controller = VirtualController.new
  end

  def test_layered_dispatching
    mt_cats = do_method_call(@layered_controller, 'mt.getCategories')
    assert_equal(["mtCat1", "mtCat2"], mt_cats)
    blogger_cats = do_method_call(@layered_controller, 'blogger.getCategories')
    assert_equal(["bloggerCat1", "bloggerCat2"], blogger_cats)
  end

  protected
    def exception_message(xmlrpc_fault_exception)
      xmlrpc_fault_exception.faultString
    end

    def is_exception?(obj)
      obj.is_a?(XMLRPC::FaultException)
    end

    def service_name(container)
      container.is_a?(DelegatedController) ? 'test_service' : 'api'
    end
end
