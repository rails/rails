module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    module Soap # :nodoc:
      def self.included(base)
        base.register_protocol(SoapProtocol)
        base.class_inheritable_option(:wsdl_service_name)
      end
      
      class SoapProtocol # :nodoc:
        def initialize
          @encoder = WS::Encoding::SoapRpcEncoding.new 'urn:ActionWebService'
          @marshaler = WS::Marshaling::SoapMarshaler.new 'urn:ActionWebService'
        end

        def unmarshal_request(ap_request)
          return nil unless has_valid_soap_action?(ap_request)
          method_name, params = @encoder.decode_rpc_call(ap_request.raw_post)
          params = params.map{|x| @marshaler.unmarshal(x)}
          service_name = ap_request.parameters['action']
          Request.new(self, method_name, params, service_name)
        end

        def marshal_response(method_name, return_value, signature_type)
          if !return_value.nil? && signature_type
            type_binding = @marshaler.register_type(signature_type)
            info = WS::ParamInfo.create(signature_type, type_binding, 0)
            return_value = @marshaler.marshal(WS::Param.new(return_value, info))
          else
            return_value = nil
          end
          body = @encoder.encode_rpc_response(method_name + 'Response', return_value)
          Response.new(body, 'text/xml')
        end

        def register_signature_type(spec)
          @marshaler.register_type(spec)
        end

        def protocol_client(api, protocol_name, endpoint_uri, options)
          return nil unless protocol_name == :soap
          ActionWebService::Client::Soap.new(api, endpoint_uri, options)
        end

        private
          def has_valid_soap_action?(request)
            return nil unless request.method == :post
            soap_action = request.env['HTTP_SOAPACTION']
            return nil unless soap_action
            soap_action = soap_action.dup
            soap_action.gsub!(/^"/, '')
            soap_action.gsub!(/"$/, '')
            soap_action.strip!
            return nil if soap_action.empty?
            soap_action
          end
        end
    end
  end
end
