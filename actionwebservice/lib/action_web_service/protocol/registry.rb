module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    HeaderAndBody = :header_and_body
    BodyOnly      = :body_only

    module Registry # :nodoc:
      def self.append_features(base) # :nodoc:
        super
        base.extend(ClassMethods)
        base.send(:include, ActionWebService::Protocol::Registry::InstanceMethods)
      end

      module ClassMethods # :nodoc:
        def register_protocol(type, klass) # :nodoc:
          case type
          when HeaderAndBody
            write_inheritable_array("header_and_body_protocols", [klass])
          when BodyOnly
            write_inheritable_array("body_only_protocols", [klass])
          else
            raise(ProtocolError, "unknown protocol type #{type}")
          end
        end
      end

      module InstanceMethods # :nodoc:
        private
          def probe_request_protocol(action_pack_request)
            (header_and_body_protocols + body_only_protocols).each do |protocol|
              protocol_request = protocol.create_protocol_request(self.class, action_pack_request)
              return protocol_request if protocol_request
            end
            raise(ProtocolError, "unsupported request message format")
          end

          def probe_protocol_client(api, protocol_name, endpoint_uri, options)
            (header_and_body_protocols + body_only_protocols).each do |protocol|
              protocol_client = protocol.create_protocol_client(api, protocol_name, endpoint_uri, options)
              return protocol_client if protocol_client
            end
            raise(ProtocolError, "unsupported client protocol :#{protocol_name}")
          end
          
          def header_and_body_protocols
            self.class.read_inheritable_attribute("header_and_body_protocols") || []
          end

          def body_only_protocols
            self.class.read_inheritable_attribute("body_only_protocols") || []
          end
      end

    end
  end
end
