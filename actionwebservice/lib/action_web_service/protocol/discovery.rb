module ActionWebService
  module Protocol
    module Discovery
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, ActionWebService::Protocol::Discovery::InstanceMethods)
      end

      module ClassMethods
        def register_protocol(klass)
          write_inheritable_array("web_service_protocols", [klass])
        end
      end

      module InstanceMethods
        private
          def discover_web_service_request(ap_request)
            (self.class.read_inheritable_attribute("web_service_protocols") || []).each do |protocol|
              protocol = protocol.new
              request = protocol.unmarshal_request(ap_request)
              return request unless request.nil?
            end
            nil
          end

          def create_web_service_client(api, protocol_name, endpoint_uri, options)
            (self.class.read_inheritable_attribute("web_service_protocols") || []).each do |protocol|
              protocol = protocol.new
              client = protocol.protocol_client(api, protocol_name, endpoint_uri, options)
              return client unless client.nil?
            end
            nil
          end
      end
    end
  end
end
