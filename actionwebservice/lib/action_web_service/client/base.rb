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
        self.perform_invocation(call_name, args)
      end

      private
        def method_name(name)
          if @api.has_api_method?(name.to_sym)
            name.to_s
          elsif @api.has_public_api_method?(name.to_s)
            @api.api_method_name(name.to_s).to_s
          end
        end
    end
  end
end
