module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    class ProtocolError < ActionWebServiceError # :nodoc:
    end

    class AbstractProtocol
      attr :marshaler
      attr :encoder

      def unmarshal_request(ap_request)
      end

      def marshal_response(method, return_value)
        body = method.encode_rpc_response(marshaler, encoder, return_value)
        Response.new(body, 'text/xml')
      end

      def protocol_client(api, protocol_name, endpoint_uri, options)
      end

      def create_action_pack_request(service_name, public_method_name, raw_body, options={})
        klass = options[:request_class] || SimpleActionPackRequest
        request = klass.new
        request.request_parameters['action'] = service_name.to_s
        request.env['RAW_POST_DATA'] = raw_body
        request.env['REQUEST_METHOD'] = 'POST'
        request.env['HTTP_CONTENT_TYPE'] = 'text/xml'
        request
      end
    end

    class SimpleActionPackRequest < ActionController::AbstractRequest
      def initialize
        @env = {}
        @qparams = {}
        @rparams = {}
        @cookies = {}
        reset_session
      end

      def query_parameters
        @qparams
      end

      def request_parameters
        @rparams
      end

      def env
        @env
      end

      def host
        ''
      end

      def cookies
        @cookies
      end

      def session
        @session
      end

      def reset_session
        @session = {}
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
