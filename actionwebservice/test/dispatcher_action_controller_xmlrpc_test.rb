require File.dirname(__FILE__) + '/abstract_dispatcher'

class TC_DispatcherActionControllerXmlRpc < Test::Unit::TestCase
  include DispatcherTest
  include DispatcherCommonTests

  def setup
    @encoder = WS::Encoding::XmlRpcEncoding.new
    @marshaler = WS::Marshaling::XmlRpcMarshaler.new
    @direct_controller = DirectController.new
    @delegated_controller = DelegatedController.new
  end

  protected
    def exception_message(xmlrpc_fault_exception)
      xmlrpc_fault_exception.faultString
    end

    def is_exception?(obj)
      obj.is_a?(XMLRPC::FaultException)
    end

    def create_ap_request(container, body, public_method_name, *args)
      test_request = ActionController::TestRequest.new
      test_request.request_parameters['action'] = service_name(container)
      test_request.env['REQUEST_METHOD'] = "POST"
      test_request.env['HTTP_CONTENTTYPE'] = 'text/xml'
      test_request.env['RAW_POST_DATA'] = body
      test_request
    end

    def service_name(container)
      container.is_a?(DelegatedController) ? 'test_service' : 'api'
    end
end
