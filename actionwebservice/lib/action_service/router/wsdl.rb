module ActionService # :nodoc:
  module Router # :nodoc:
    module Wsdl # :nodoc:
      def self.append_features(base) # :nodoc:
        base.class_eval do 
          class << self
            alias_method :inherited_without_wsdl, :inherited
          end
        end
        base.extend(ClassMethods)
      end

      module ClassMethods
        def inherited(child)
          inherited_without_wsdl(child)
          child.send(:include, ActionService::Router::Wsdl::InstanceMethods)
        end
      end

      module InstanceMethods # :nodoc:
        XsdNs             = 'http://www.w3.org/2001/XMLSchema'
        WsdlNs            = 'http://schemas.xmlsoap.org/wsdl/'
        SoapNs            = 'http://schemas.xmlsoap.org/wsdl/soap/'
        SoapEncodingNs    = 'http://schemas.xmlsoap.org/soap/encoding/'
        SoapHttpTransport = 'http://schemas.xmlsoap.org/soap/http'

        def wsdl
          case @request.method
          when :get
            begin
              host_name = @request.env['HTTP_HOST']||@request.env['SERVER_NAME']
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
                      when mapping.is_a?(ActionService::Protocol::Soap::SoapArrayMapping)
                        xm.xsd(:complexType, 'name' => mapping.type_name) do
                          xm.xsd(:complexContent) do
                            xm.xsd(:restriction, 'base' => 'soapenc:Array') do
                              xm.xsd(:attribute, 'ref' => 'soapenc:arrayType',
                                                 'wsdl:arrayType' => mapping.element_mapping.qualified_type_name + '[]')
                            end
                          end
                        end
                      when mapping.is_a?(ActionService::Protocol::Soap::SoapMapping)
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
