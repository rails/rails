require File.dirname(__FILE__) + '/abstract_unit'
require 'soap/rpc/element'

class SoapTestError < StandardError
end

class AbstractSoapTest < Test::Unit::TestCase
  def default_test
  end

  protected
    def service_name
      raise NotImplementedError
    end

    def do_soap_call(public_method_name, *args)
      mapper = @container.class.soap_mapper
      param_def = []
      i = 1
      args.each do |arg|
        mapping = mapper.lookup(arg.class)
        param_def << ["in", "param#{i}", mapping.registry_mapping]
        i += 1
      end
      qname = XSD::QName.new('urn:ActionWebService', public_method_name)
      request = SOAP::RPC::SOAPMethodRequest.new(qname, param_def)
      soap_args = []
      i = 1
      args.each do |arg|
        soap_args << ["param#{i}", SOAP::Mapping.obj2soap(arg)]
        i += 1
      end
      request.set_param(soap_args)
      header = SOAP::SOAPHeader.new
      body = SOAP::SOAPBody.new(request)
      envelope = SOAP::SOAPEnvelope.new(header, body)
      raw_request = SOAP::Processor.marshal(envelope)
      test_request = ActionController::TestRequest.new
      test_request.request_parameters['action'] = service_name
      test_request.env['REQUEST_METHOD'] = "POST"
      test_request.env['HTTP_CONTENTTYPE'] = 'text/xml'
      test_request.env['HTTP_SOAPACTION'] = "/soap/#{service_name}/#{public_method_name}"
      test_request.env['RAW_POST_DATA'] = raw_request
      test_response = ActionController::TestResponse.new
      response = yield test_request, test_response
      raw_body = response.respond_to?(:body) ? response.body : response.raw_body
      envelope = SOAP::Processor.unmarshal(raw_body)
      if envelope
        if envelope.body.response
          SOAP::Mapping.soap2obj(envelope.body.response)
        else
          nil
        end
      else
        raise(SoapTestError, "empty/invalid body from server")
      end
    end
end
