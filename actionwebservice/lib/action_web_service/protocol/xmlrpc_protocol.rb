module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    module XmlRpc # :nodoc:
      def self.included(base)
        base.register_protocol(XmlRpcProtocol)
      end
      
      class XmlRpcProtocol < AbstractProtocol # :nodoc:
        def initialize
          @encoder = WS::Encoding::XmlRpcEncoding.new
          @marshaler = WS::Marshaling::XmlRpcMarshaler.new
        end

        def unmarshal_request(ap_request)
          method_name, params = @encoder.decode_rpc_call(ap_request.raw_post)
          params = params.map{|x| @marshaler.unmarshal(x)}
          service_name = ap_request.parameters['action']
          Request.new(self, method_name, params, service_name)
        end

        def protocol_client(api, protocol_name, endpoint_uri, options)
          return nil unless protocol_name == :xmlrpc
          ActionWebService::Client::XmlRpc.new(api, endpoint_uri, options)
        end
      end
    end
  end
end
