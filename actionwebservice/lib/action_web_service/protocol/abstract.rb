module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    class ProtocolError < ActionWebServiceError # :nodoc:
    end

    class Request # :nodoc:
      attr :protocol
      attr :method_name
      attr :method_params
      attr :service_name

      def initialize(protocol, method_name, method_params, service_name)
        @protocol = protocol
        @method_name = method_name
        @method_params = method_params
        @service_name = service_name
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
