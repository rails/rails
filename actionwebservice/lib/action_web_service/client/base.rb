module ActionWebService # :nodoc:
  module Client # :nodoc:
    class ClientError < StandardError # :nodoc:
    end

    class Base # :nodoc:
      def initialize(api, endpoint_uri)
        @api = api
        @endpoint_uri = endpoint_uri
      end

      def method_missing(name, *args) # :nodoc:
        call_name = method_name(name)
        return super(name, *args) if call_name.nil?
        perform_invocation(call_name, args)
      end

      protected
        def perform_invocation(method_name, args) # :nodoc:
          raise NotImplementedError, "use a protocol-specific client"
        end

      private
        def method_name(name)
          if @api.has_api_method?(name.to_sym)
            name.to_s
          elsif @api.has_public_api_method?(name.to_s)
            @api.api_method_name(name.to_s).to_s
          else
            nil
          end
        end

        def lookup_class(klass)
          klass.is_a?(Hash) ?  klass.values[0] : klass
        end
    end
  end
end
