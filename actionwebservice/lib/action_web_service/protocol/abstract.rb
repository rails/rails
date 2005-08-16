module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    class ProtocolError < ActionWebServiceError # :nodoc:
    end

    class AbstractProtocol # :nodoc:
      def setup(controller)
      end

      def decode_action_pack_request(action_pack_request)
      end

      def encode_action_pack_request(service_name, public_method_name, raw_body, options={})
        klass = options[:request_class] || SimpleActionPackRequest
        request = klass.new
        request.request_parameters['action'] = service_name.to_s
        request.env['RAW_POST_DATA'] = raw_body
        request.env['REQUEST_METHOD'] = 'POST'
        request.env['HTTP_CONTENT_TYPE'] = 'text/xml'
        request
      end

      def decode_request(raw_request, service_name, protocol_options={})
      end

      def encode_request(method_name, params, param_types)
      end

      def decode_response(raw_response)
      end

      def encode_response(method_name, return_value, return_type, protocol_options={})
      end

      def protocol_client(api, protocol_name, endpoint_uri, options)
      end

      def register_api(api)
      end
    end

    class Request # :nodoc:
      attr :protocol
      attr_accessor :method_name
      attr_accessor :method_params
      attr :service_name
      attr_accessor :api
      attr_accessor :api_method
      attr :protocol_options

      def initialize(protocol, method_name, method_params, service_name, api=nil, api_method=nil, protocol_options=nil)
        @protocol = protocol
        @method_name = method_name
        @method_params = method_params
        @service_name = service_name
        @api = api
        @api_method = api_method
        @protocol_options = protocol_options || {}
      end
    end

    class Response # :nodoc:
      attr :body
      attr :content_type
      attr :return_value

      def initialize(body, content_type, return_value)
        @body = body
        @content_type = content_type
        @return_value = return_value
      end
    end

    class SimpleActionPackRequest < ActionController::AbstractRequest # :nodoc:
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
  end
end
