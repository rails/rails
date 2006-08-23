require File.dirname(__FILE__) + '/abstract_dispatcher'

class TC_DispatcherActionControllerXmlRpc < Test::Unit::TestCase
  include DispatcherTest
  include DispatcherCommonTests

  def setup
    @direct_controller = DirectController.new
    @delegated_controller = DelegatedController.new
    @layered_controller = LayeredController.new
    @virtual_controller = VirtualController.new
    @protocol = ActionWebService::Protocol::XmlRpc::XmlRpcProtocol.create(@direct_controller)
  end

  def test_layered_dispatching
    mt_cats = do_method_call(@layered_controller, 'mt.getCategories')
    assert_equal(["mtCat1", "mtCat2"], mt_cats)
    blogger_cats = do_method_call(@layered_controller, 'blogger.getCategories')
    assert_equal(["bloggerCat1", "bloggerCat2"], blogger_cats)
  end

  def test_multicall
    response = do_method_call(@layered_controller, 'system.multicall', [
      {'methodName' => 'mt.getCategories'},
      {'methodName' => 'blogger.getCategories'},
      {'methodName' => 'mt.bool'},
      {'methodName' => 'blogger.str', 'params' => ['2000']},
      {'methodName' => 'mt.alwaysFail'},
      {'methodName' => 'blogger.alwaysFail'},
      {'methodName' => 'mt.blah'},
      {'methodName' => 'blah.blah'},
      {'methodName' => 'mt.person'}
    ])
    assert_equal [
      [["mtCat1", "mtCat2"]],
      [["bloggerCat1", "bloggerCat2"]],
      [true],
      ["2500"],
      {"faultCode" => 3, "faultString" => "MT AlwaysFail"},
      {"faultCode" => 3, "faultString" => "Blogger AlwaysFail"},
      {"faultCode" => 4, "faultMessage" => "no such method 'blah' on API DispatcherTest::MTAPI"},
      {"faultCode" => 4, "faultMessage" => "no such web service 'blah'"},
      [{"name"=>"person1", "id"=>1}]
    ], response
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
