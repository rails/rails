module ActionService # :nodoc:
  module Protocol # :nodoc:
    CheckedMessage = :checked
    UncheckedMessage = :unchecked

    class ProtocolError < ActionService::ActionServiceError # :nodoc:
    end

    class AbstractProtocol # :nodoc:
      attr :container_class

      def initialize(container_class)
        @container_class = container_class
      end

      def unmarshal_request(protocol_request)
        raise NotImplementedError
      end

      def marshal_response(protocol_request, return_value)
        raise NotImplementedError
      end

      def marshal_exception(exception)
        raise NotImplementedError
      end

      def self.create_protocol_request(container_class, action_pack_request)
        nil
      end

      def self.create_protocol_client(api, protocol_name, endpoint_uri, options)
        nil
      end
    end

    class AbstractProtocolMessage # :nodoc:
      attr_accessor :signature
      attr_accessor :return_signature
      attr_accessor :type
      attr :options

      def initialize(options={})
        @signature = @return_signature = nil
        @options = options
        @type = @options[:type] || CheckedMessage
      end

      def signature=(value)
        return if value.nil?
        @signature = []
        value.each do |klass|
          if klass.is_a?(Hash)
            @signature << klass.values.shift
          else
            @signature << klass
          end
        end
        @signature
      end

      def checked?
        @type == CheckedMessage
      end

      def check_parameter_types(values, signature)
        return unless checked? && signature
        unless signature.length == values.length
          raise(ProtocolError, "Signature and parameter lengths mismatch")
        end
        (1..signature.length).each do |i|
          check_compatibility(signature[i-1], values[i-1].class)
        end
      end

      def check_compatibility(expected_class, received_class)
        return if \
            (expected_class == TrueClass or expected_class == FalseClass) and \
            (received_class == TrueClass or received_class == FalseClass)
        unless received_class.ancestors.include?(expected_class) or \
               expected_class.ancestors.include?(received_class)
          raise(ProtocolError, "value of type #{received_class.name} is not " +
                               "compatible with expected type #{expected_class.name}")
        end
      end
    end

    class ProtocolRequest < AbstractProtocolMessage # :nodoc:
      attr :protocol
      attr :raw_body

      attr_accessor :web_service_name
      attr_accessor :public_method_name
      attr_accessor :content_type

      def initialize(protocol, raw_body, web_service_name, public_method_name, content_type, options={})
        super(options)
        @protocol = protocol
        @raw_body = raw_body
        @web_service_name = web_service_name
        @public_method_name = public_method_name
        @content_type = content_type
      end

      def unmarshal
        @protocol.unmarshal_request(self)
      end

      def marshal(return_value)
        @protocol.marshal_response(self, return_value)
      end
    end

    class ProtocolResponse < AbstractProtocolMessage # :nodoc:
      attr :protocol
      attr :raw_body

      attr_accessor :content_type

      def initialize(protocol, raw_body, content_type, options={})
        super(options)
        @protocol = protocol
        @raw_body = raw_body
        @content_type = content_type
      end
    end
  end
end
