require 'soap/processor'
require 'soap/mapping'
require 'soap/rpc/element'

module WS
  module Encoding
    class SoapRpcError < WSError
    end

    class SoapRpcEncoding < AbstractEncoding
      attr_accessor :method_namespace

      def initialize(method_namespace='')
        @method_namespace = method_namespace
      end

      def encode_rpc_call(method_name, foreign_params)
        qname = create_method_qname(method_name)
        param_def = []
        params = foreign_params.map do |p|
          param_def << ['in', p.param.info.name, p.param.info.data.mapping]
          [p.param.info.name, p.soap_object]
        end
        request = SOAP::RPC::SOAPMethodRequest.new(qname, param_def)
        request.set_param(params)
        envelope = create_soap_envelope(request)
        SOAP::Processor.marshal(envelope)
      end

      def decode_rpc_call(obj)
        envelope = SOAP::Processor.unmarshal(obj)
        unless envelope
          raise(SoapRpcError, "Malformed SOAP request")
        end
        request = envelope.body.request
        method_name = request.elename.name
        params = request.collect do |key, value|
          info = ParamInfo.new(key, nil, nil)
          param = Param.new(nil, info)
          Marshaling::SoapForeignObject.new(param, request[key])
        end
        [method_name, params]
      end

      def encode_rpc_response(method_name, return_value)
        response = nil
        qname = create_method_qname(method_name)
        if return_value.nil?
          response = SOAP::RPC::SOAPMethodResponse.new(qname, nil)
        else
          param = return_value.param
          soap_object = return_value.soap_object
          param_def = [['retval', 'return', param.info.data.mapping]]
          if soap_object.is_a?(SOAP::SOAPFault)
            response = soap_object
          else
            response = SOAP::RPC::SOAPMethodResponse.new(qname, param_def)
            response.retval = soap_object
          end
        end
        envelope = create_soap_envelope(response)
        SOAP::Processor.marshal(envelope)
      end

      def decode_rpc_response(obj)
        envelope = SOAP::Processor.unmarshal(obj)
        unless envelope
          raise(SoapRpcError, "Malformed SOAP response")
        end
        method_name = envelope.body.request.elename.name
        return_value = envelope.body.response
        info = ParamInfo.new('return', nil, nil)
        param = Param.new(nil, info)
        return_value = Marshaling::SoapForeignObject.new(param, return_value)
        [method_name, return_value]
      end

      private
        def create_soap_envelope(body)
          header = SOAP::SOAPHeader.new
          body = SOAP::SOAPBody.new(body)
          SOAP::SOAPEnvelope.new(header, body)
        end

        def create_method_qname(method_name)
          XSD::QName.new(@method_namespace, method_name)
        end
    end
  end
end
