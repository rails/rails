module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    module XmlRpc # :nodoc:
      def self.included(base)
        base.register_protocol(XmlRpcProtocol)
      end
      
      class XmlRpcProtocol # :nodoc:
        attr :marshaler

        def initialize
          @encoder = WS::Encoding::XmlRpcEncoding.new
          @marshaler = WS::Marshaling::XmlRpcMarshaler.new
        end

        def unmarshal_request(ap_request)
          method_name, params = @encoder.decode_rpc_call(ap_request.raw_post)
          params = params.map{|x| @marshaler.unmarshal(x)}
          service_name = ap_request.parameters['action']
          Request.new(self, method_name, params, service_name)
        rescue
          nil
        end

        def marshal_response(method_name, return_value, signature_type)
          if !return_value.nil? && signature_type
            type_binding = @marshaler.register_type(signature_type)
            info = WS::ParamInfo.create(signature_type, type_binding, 0)
            return_value = @marshaler.marshal(WS::Param.new(return_value, info))
          else
            return_value = nil
          end
          body = @encoder.encode_rpc_response(method_name, return_value)
          Response.new(body, 'text/xml')
        end

        def register_signature_type(spec)
          nil
        end

        def protocol_client(api, protocol_name, endpoint_uri, options)
          return nil unless protocol_name == :xmlrpc
          ActionWebService::Client::XmlRpc.new(api, endpoint_uri, options)
        end
      end
    end
  end
end
