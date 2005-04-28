require 'action_web_service/protocol/soap_protocol/marshaler'

module ActionWebService # :nodoc:
  module Protocol # :nodoc:
    module Soap # :nodoc:
      def self.included(base)
        base.register_protocol(SoapProtocol)
        base.class_inheritable_option(:wsdl_service_name)
      end
      
      class SoapProtocol < AbstractProtocol # :nodoc:
        def marshaler
          @marshaler ||= SoapMarshaler.new
        end

        def decode_action_pack_request(action_pack_request)
          return nil unless soap_action = has_valid_soap_action?(action_pack_request)
          service_name = action_pack_request.parameters['action']
          protocol_options = { :soap_action => soap_action }
          decode_request(action_pack_request.raw_post, service_name, protocol_options)
        end

        def encode_action_pack_request(service_name, public_method_name, raw_body, options={})
          request = super
          request.env['HTTP_SOAPACTION'] = '/soap/%s/%s' % [service_name, public_method_name]
          request
        end

        def decode_request(raw_request, service_name, protocol_options=nil)
          envelope = SOAP::Processor.unmarshal(raw_request)
          unless envelope
            raise ProtocolError, "Failed to parse SOAP request message"
          end
          request = envelope.body.request
          method_name = request.elename.name
          params = request.collect{ |k, v| marshaler.soap_to_ruby(request[k]) }
          Request.new(self, method_name, params, service_name, nil, nil, protocol_options)
        end

        def encode_request(method_name, params, param_types)
          param_types.each{ |type| marshaler.register_type(type) } if param_types
          qname = XSD::QName.new(marshaler.type_namespace, method_name)
          param_def = []
          if param_types
            params = param_types.zip(params).map do |type, param|
              param_def << ['in', type.name, marshaler.lookup_type(type).mapping]
              [type.name, marshaler.ruby_to_soap(param)]
            end
          else
            params = []
          end
          request = SOAP::RPC::SOAPMethodRequest.new(qname, param_def)
          request.set_param(params)
          envelope = create_soap_envelope(request)
          SOAP::Processor.marshal(envelope)
        end

        def decode_response(raw_response)
          envelope = SOAP::Processor.unmarshal(raw_response)
          unless envelope
            raise ProtocolError, "Failed to parse SOAP request message"
          end
          method_name = envelope.body.request.elename.name
          return_value = envelope.body.response
          return_value = marshaler.soap_to_ruby(return_value) unless return_value.nil?
          [method_name, return_value]
        end

        def encode_response(method_name, return_value, return_type)
          if return_type
            return_binding = marshaler.register_type(return_type)
            marshaler.annotate_arrays(return_binding, return_value)
          end
          qname = XSD::QName.new(marshaler.type_namespace, method_name)
          if return_value.nil?
            response = SOAP::RPC::SOAPMethodResponse.new(qname, nil)
          else
            if return_value.is_a?(Exception)
              detail = SOAP::Mapping::SOAPException.new(return_value)
              response = SOAP::SOAPFault.new(
                SOAP::SOAPQName.new('%s:%s' % [SOAP::SOAPNamespaceTag, 'Server']),
                SOAP::SOAPString.new(return_value.to_s),
                SOAP::SOAPString.new(self.class.name),
                marshaler.ruby_to_soap(detail))
            else
              if return_type
                param_def = [['retval', 'return', marshaler.lookup_type(return_type).mapping]]
                response = SOAP::RPC::SOAPMethodResponse.new(qname, param_def)
                response.retval = marshaler.ruby_to_soap(return_value)
              else
                response = SOAP::RPC::SOAPMethodResponse.new(qname, nil)
              end
            end
          end
          envelope = create_soap_envelope(response)
          Response.new(SOAP::Processor.marshal(envelope), 'text/xml; charset=utf-8', return_value)
        end

        def protocol_client(api, protocol_name, endpoint_uri, options={})
          return nil unless protocol_name == :soap
          ActionWebService::Client::Soap.new(api, endpoint_uri, options)
        end

        def register_api(api)
          api.api_methods.each do |name, method|
            method.expects.each{ |type| marshaler.register_type(type) } if method.expects
            method.returns.each{ |type| marshaler.register_type(type) } if method.returns
          end
        end

        private
          def has_valid_soap_action?(request)
            return nil unless request.method == :post
            soap_action = request.env['HTTP_SOAPACTION']
            return nil unless soap_action
            soap_action = soap_action.dup
            soap_action.gsub!(/^"/, '')
            soap_action.gsub!(/"$/, '')
            soap_action.strip!
            return nil if soap_action.empty?
            soap_action
          end

          def create_soap_envelope(body)
            header = SOAP::SOAPHeader.new
            body = SOAP::SOAPBody.new(body)
            SOAP::SOAPEnvelope.new(header, body)
          end
      end
    end
  end
end
