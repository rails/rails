require 'test/unit'

module Test
  module Unit
    class TestCase # :nodoc:
      private
        # invoke the specified API method
        def invoke_direct(method_name, *args)
          prepare_request('api', 'api', method_name, *args)
          @controller.process(@request, @response)
          decode_rpc_response
        end
        alias_method :invoke, :invoke_direct

        # invoke the specified API method on the specified service
        def invoke_delegated(service_name, method_name, *args)
          prepare_request(service_name.to_s, service_name, method_name, *args)
          @controller.process(@request, @response)
          decode_rpc_response
        end

        # invoke the specified layered API method on the correct service
        def invoke_layered(service_name, method_name, *args)
          if protocol == :soap
            raise "SOAP protocol support for :layered dispatching mode is not available"
          end
          prepare_request('api', service_name, method_name, *args)
          @controller.process(@request, @response)
          decode_rpc_response
        end

        # ---------------------- internal ---------------------------

        def prepare_request(action, service_name, api_method_name, *args)
          @request.request_parameters['action'] = action
          @request.env['REQUEST_METHOD'] = 'POST'
          @request.env['HTTP_CONTENT_TYPE'] = 'text/xml'
          @request.env['RAW_POST_DATA'] = encode_rpc_call(service_name, api_method_name, *args)
          case protocol
          when :soap
            soap_action = "/#{@controller.controller_name}/#{service_name}/#{public_method_name(service_name, api_method_name)}" 
            @request.env['HTTP_SOAPACTION'] = soap_action
          when :xmlrpc
            @request.env.delete('HTTP_SOAPACTION')
          end
        end

        def encode_rpc_call(service_name, api_method_name, *args)
          case @controller.web_service_dispatching_mode
          when :direct
            api = @controller.class.web_service_api
          when :delegated, :layered
            api = @controller.web_service_object(service_name.to_sym).class.web_service_api
          end
          info = api.api_methods[api_method_name.to_sym]
          ((info[:expects] || []) + (info[:returns] || [])).each do |spec|
            marshaler.register_type spec
          end
          expects = info[:expects]
          args = args.dup
          (0..(args.length-1)).each do |i|
            type_binding = marshaler.register_type(expects ? expects[i] : args[i].class)
            info = WS::ParamInfo.create(expects ? expects[i] : args[i].class, type_binding, i)
            args[i] = marshaler.marshal(WS::Param.new(args[i], info))
          end
          encoder.encode_rpc_call(public_method_name(service_name, api_method_name), args)
        end

        def decode_rpc_response
          public_method_name, return_value = encoder.decode_rpc_response(@response.body)
          result = marshaler.unmarshal(return_value).value
          unless @return_exceptions
            exception = is_exception?(result)
            raise exception if exception
          end
          result
        end

        def public_method_name(service_name, api_method_name)
          public_name = service_api(service_name).public_api_method_name(api_method_name)
          if @controller.web_service_dispatching_mode == :layered
            '%s.%s' % [service_name.to_s, public_name]
          else
            public_name
          end
        end

        def service_api(service_name)
          case @controller.web_service_dispatching_mode
          when :direct
            @controller.class.web_service_api
          when :delegated, :layered
            @controller.web_service_object(service_name.to_sym).class.web_service_api
          end
        end

        def protocol
          @protocol ||= :soap
        end

        def marshaler
          case protocol
          when :soap
            @soap_marshaler ||= WS::Marshaling::SoapMarshaler.new 'urn:ActionWebService'
          when :xmlrpc
            @xmlrpc_marshaler ||= WS::Marshaling::XmlRpcMarshaler.new
          end
        end

        def encoder
          case protocol
          when :soap
            @soap_encoder ||= WS::Encoding::SoapRpcEncoding.new 'urn:ActionWebService'
          when :xmlrpc
            @xmlrpc_encoder ||= WS::Encoding::XmlRpcEncoding.new
          end
        end

        def is_exception?(obj)
          case protocol
          when :soap
            (obj.respond_to?(:detail) && obj.detail.respond_to?(:cause) && \
            obj.detail.cause.is_a?(Exception)) ? obj.detail.cause : nil
          when :xmlrpc
            obj.is_a?(XMLRPC::FaultException) ? obj : nil
          end
        end
    end
  end
end
