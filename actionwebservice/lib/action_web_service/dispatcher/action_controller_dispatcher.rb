module ActionWebService # :nodoc:
  module Dispatcher # :nodoc:
    module ActionController # :nodoc:
      def self.append_features(base) # :nodoc:
        super
        base.class_eval do
          class << self
            alias_method :inherited_without_action_controller, :inherited
          end
          alias_method :before_direct_invoke_without_action_controller, :before_direct_invoke
          alias_method :after_direct_invoke_without_action_controller, :after_direct_invoke
        end
        base.add_web_service_api_callback do |klass, api|
          if klass.web_service_dispatching_mode == :direct
            klass.class_eval <<-EOS
              def api
                controller_dispatch_web_service_request
              end
            EOS
          end
        end
        base.add_web_service_definition_callback do |klass, name, info|
          if klass.web_service_dispatching_mode == :delegated
            klass.class_eval <<-EOS
              def #{name}
                controller_dispatch_web_service_request
              end
            EOS
          end
        end
        base.extend(ClassMethods)
        base.send(:include, ActionWebService::Dispatcher::ActionController::Invocation)
      end

      module ClassMethods # :nodoc:
        def inherited(child)
          inherited_without_action_controller(child)
          child.send(:include, ActionWebService::Dispatcher::ActionController::WsdlGeneration)
        end
      end

      module Invocation # :nodoc:
        private
          def controller_dispatch_web_service_request
            request, response, elapsed, exception = dispatch_web_service_request(@request)
            if response
              begin
                log_request(request)
                log_error(exception) if exception && logger
                log_response(response, elapsed)
                response_options = { :type => response.content_type, :disposition => 'inline' }
                send_data(response.raw_body, response_options)
              rescue Exception => e
                log_error(e) unless logger.nil?
                render_text("Internal protocol error", "500 Internal Server Error")
              end
            else
              logger.error("No response available") unless logger.nil?
              render_text("Internal protocol error", "500 Internal Server Error")
            end
          end

          def before_direct_invoke(request)
            before_direct_invoke_without_action_controller(request)
            @params ||= {}
            signature = request.signature
            if signature && (expects = request.signature[:expects])
              (0..(@method_params.size-1)).each do |i|
                if expects[i].is_a?(Hash)
                  @params[expects[i].keys[0].to_s] = @method_params[i]
                else
                  @params['param%d' % i] = @method_params[i]
                end
              end
            end
            @params['action'] = request.method_name.to_s
            @session ||= {}
            @assigns ||= {}
            return nil if before_action == false
            true
          end

          def after_direct_invoke(request)
            after_direct_invoke_without_action_controller(request)
            after_action
          end

          def log_request(request)
            unless logger.nil? || request.nil?
              logger.debug("\nWeb Service Request:")
              indented = request.raw_body.split(/\n/).map{|x| "  #{x}"}.join("\n")
              logger.debug(indented)
            end
          end

          def log_response(response, elapsed)
            unless logger.nil? || response.nil?
              logger.debug("\nWeb Service Response (%f):" % elapsed)
              indented = response.raw_body.split(/\n/).map{|x| "  #{x}"}.join("\n")
              logger.debug(indented)
            end
          end

          unless method_defined?(:logger)
            def logger; @logger; end
          end
      end

      module WsdlGeneration # :nodoc:
        XsdNs             = 'http://www.w3.org/2001/XMLSchema'
        WsdlNs            = 'http://schemas.xmlsoap.org/wsdl/'
        SoapNs            = 'http://schemas.xmlsoap.org/wsdl/soap/'
        SoapEncodingNs    = 'http://schemas.xmlsoap.org/soap/encoding/'
        SoapHttpTransport = 'http://schemas.xmlsoap.org/soap/http'

        def wsdl
          case @request.method
          when :get
            begin
              host_name = @request.env['HTTP_HOST'] || @request.env['SERVER_NAME']
              uri = "http://#{host_name}/#{controller_name}/"
              soap_action_base = "/#{controller_name}"
              xml = to_wsdl(self, uri, soap_action_base)
              send_data(xml, :type => 'text/xml', :disposition => 'inline')
            rescue Exception => e
              log_error e unless logger.nil?
              render_text('', "500 #{e.message}")
            end
          when :post
            render_text('', "500 POST not supported")
          end
        end

        private
          def to_wsdl(container, uri, soap_action_base)
            wsdl = ""
  
            web_service_dispatching_mode = container.web_service_dispatching_mode
            mapper = container.class.soap_mapper
            namespace = mapper.custom_namespace
            wsdl_service_name = namespace.split(/:/)[1]
  
            services = {}
            mapper.map_container_services(container) do |name, api, api_methods|
              services[name] = [api, api_methods]
            end
            custom_types = mapper.custom_types
  
  
            xm = Builder::XmlMarkup.new(:target => wsdl, :indent => 2)
            xm.instruct!
  
            xm.definitions('name' => wsdl_service_name,
                           'targetNamespace' => namespace,
                           'xmlns:typens'    => namespace,
                           'xmlns:xsd'       => XsdNs,
                           'xmlns:soap'      => SoapNs,
                           'xmlns:soapenc'   => SoapEncodingNs,
                           'xmlns:wsdl'      => WsdlNs,
                           'xmlns'           => WsdlNs) do
  
              # Custom type XSD generation
              if custom_types.size > 0
                xm.types do
                  xm.xsd(:schema, 'xmlns' => XsdNs, 'targetNamespace' => namespace) do
                    custom_types.each do |klass, mapping|
                      case
                      when mapping.is_a?(ActionWebService::Protocol::Soap::SoapArrayMapping)
                        xm.xsd(:complexType, 'name' => mapping.type_name) do
                          xm.xsd(:complexContent) do
                            xm.xsd(:restriction, 'base' => 'soapenc:Array') do
                              xm.xsd(:attribute, 'ref' => 'soapenc:arrayType',
                                                 'wsdl:arrayType' => mapping.element_mapping.qualified_type_name + '[]')
                            end
                          end
                        end
                      when mapping.is_a?(ActionWebService::Protocol::Soap::SoapMapping)
                        xm.xsd(:complexType, 'name' => mapping.type_name) do
                          xm.xsd(:all) do
                            mapping.each_attribute do |name, type_name|
                              xm.xsd(:element, 'name' => name, 'type' => type_name)
                            end
                          end
                        end
                      else
                        raise(WsdlError, "unsupported mapping type #{mapping.class.name}")
                      end
                    end
                  end
                end
              end
  
              services.each do |service_name, service_values|
                service_api, api_methods = service_values
                # Parameter list message definitions
                api_methods.each do |method_name, method_signature|
                  gen = lambda do |msg_name, direction|
                    xm.message('name' => msg_name) do
                      sym = nil
                      if direction == :out
                        if method_signature[:returns]
                          xm.part('name' => 'return', 'type' => method_signature[:returns][0].qualified_type_name)
                        end
                      else
                        mapping_list = method_signature[:expects]
                        i = 1
                        mapping_list.each do |mapping|
                          if mapping.is_a?(Hash)
                            param_name = mapping.keys.shift
                            mapping = mapping.values.shift
                          else
                            param_name = "param#{i}"
                          end
                          xm.part('name' => param_name, 'type' => mapping.qualified_type_name)
                          i += 1
                        end if mapping_list
                      end
                    end
                  end
                  public_name = service_api.public_api_method_name(method_name)
                  gen.call(public_name, :in)
                  gen.call("#{public_name}Response", :out)
                end
  
                # Declare the port
                port_name = port_name_for(wsdl_service_name, service_name)
                xm.portType('name' => port_name) do
                  api_methods.each do |method_name, method_signature|
                    public_name = service_api.public_api_method_name(method_name)
                    xm.operation('name' => public_name) do
                      xm.input('message' => "typens:#{public_name}")
                      xm.output('message' => "typens:#{public_name}Response")
                    end
                  end
                end
  
                # Bind the port to SOAP
                binding_name = binding_name_for(wsdl_service_name, service_name)
                xm.binding('name' => binding_name, 'type' => "typens:#{port_name}") do
                  xm.soap(:binding, 'style' => 'rpc', 'transport' => SoapHttpTransport)
                  api_methods.each do |method_name, method_signature|
                    public_name = service_api.public_api_method_name(method_name)
                    xm.operation('name' => public_name) do
                      case web_service_dispatching_mode
                      when :direct
                        soap_action = soap_action_base + "/api/" + public_name
                      when :delegated
                        soap_action = soap_action_base \
                                    + "/" + service_name.to_s \
                                    + "/" + public_name
                      end
                      xm.soap(:operation, 'soapAction' => soap_action)
                      xm.input do
                        xm.soap(:body,
                                'use'           => 'encoded',
                                'namespace'     => namespace,
                                'encodingStyle' => SoapEncodingNs)
                      end
                      xm.output do
                        xm.soap(:body,
                                'use'           => 'encoded',
                                'namespace'     => namespace,
                                'encodingStyle' => SoapEncodingNs)
                      end
                    end
                  end
                end
              end
  
              # Define the service
              xm.service('name' => "#{wsdl_service_name}Service") do
                services.each do |service_name, service_values|
                  port_name = port_name_for(wsdl_service_name, service_name)
                  binding_name = binding_name_for(wsdl_service_name,  service_name)
                  case web_service_dispatching_mode
                  when :direct
                    binding_target = 'api'
                  when :delegated
                    binding_target = service_name.to_s
                  end
                  xm.port('name' => port_name, 'binding' => "typens:#{binding_name}") do
                    xm.soap(:address, 'location' => "#{uri}#{binding_target}")
                  end
                end
              end
            end
          end

          def port_name_for(wsdl_service_name, service_name)
            "#{wsdl_service_name}#{service_name.to_s.camelize}Port"
          end

          def binding_name_for(wsdl_service_name, service_name)
            "#{wsdl_service_name}#{service_name.to_s.camelize}Binding"
          end
      end
    end
  end
end
