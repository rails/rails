module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    class ProtocolError < ActionWebServiceError # :nodoc:
    end

    class AbstractProtocol
      attr :marshaler
      attr :encoder

      def marshal_response(method, return_value)
        body = method.encode_rpc_response(marshaler, encoder, return_value)
        Response.new(body, 'text/xml')
      end
    end

    class Request # :nodoc:
      attr :protocol
      attr :method_name
      attr :method_params
      attr :service_name
      attr_accessor :api
      attr_accessor :api_method

      def initialize(protocol, method_name, method_params, service_name, api=nil, api_method=nil)
        @protocol = protocol
        @method_name = method_name
        @method_params = method_params
        @service_name = service_name
        @api = api
        @api_method = api_method
      end
    end

    class Response # :nodoc:
      attr :body
      attr :content_type

      def initialize(body, content_type)
        @body = body
        @content_type = content_type
      end
    end
  end
end
