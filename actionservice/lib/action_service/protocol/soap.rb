require 'soap/processor'
require 'soap/mapping'
require 'soap/rpc/element'
require 'xsd/datatypes'
require 'xsd/ns'
require 'singleton'

module ActionService # :nodoc:
  module Protocol # :nodoc:
    module Soap # :nodoc:
      class ProtocolError < ActionService::ActionServiceError # :nodoc:
      end

      def self.append_features(base) # :nodoc:
        super
        base.register_protocol(HeaderAndBody, SoapProtocol)
        base.extend(ClassMethods)
        base.wsdl_service_name('ActionService')
      end

      module ClassMethods
        # Specifies the WSDL service name to use when generating WSDL. Highly
        # recommended that you set this value, or code generators may generate
        # classes with very generic names.
        #
        # === Example
        #   class MyController < ActionController::Base
        #     wsdl_service_name 'MyService'
        #   end
        def wsdl_service_name(name)
          write_inheritable_attribute("soap_mapper", SoapMapper.new("urn:#{name}"))
        end

        def soap_mapper # :nodoc:
          read_inheritable_attribute("soap_mapper")
        end
      end

      class SoapProtocol < AbstractProtocol # :nodoc:
        attr :mapper

        def initialize(mapper)
          @mapper = mapper
        end

        def self.create_protocol_request(container_class, action_pack_request)
          soap_action = extract_soap_action(action_pack_request)
          return nil unless soap_action
          service_name = action_pack_request.parameters['action']
          public_method_name = soap_action.gsub(/^[\/]+/, '').split(/[\/]+/)[-1]
          content_type = action_pack_request.env['HTTP_CONTENT_TYPE']
          content_type ||= 'text/xml'
          protocol = SoapProtocol.new(container_class.soap_mapper)
          ProtocolRequest.new(protocol,
                              action_pack_request.raw_post,
                              service_name.to_sym,
                              public_method_name,
                              content_type)
        end

        def self.create_protocol_client(api, protocol_name, endpoint_uri, options)
          return nil unless protocol_name.to_s.downcase.to_sym == :soap
          ActionService::Client::Soap.new(api, endpoint_uri, options)
        end

        def unmarshal_request(protocol_request)
          unmarshal = lambda do
            envelope = SOAP::Processor.unmarshal(protocol_request.raw_body)
            request = envelope.body.request
            values = request.collect{|k, v| request[k]}
            soap_to_ruby_array(values)
          end
          signature = protocol_request.signature
          if signature
            map_signature_types(signature)
            values = unmarshal.call
            signature = signature.map{|x|mapper.lookup(x).ruby_klass}
            protocol_request.check_parameter_types(values, signature)
            values
          else
            if protocol_request.checked?
              []
            else
              unmarshal.call
            end
          end
        end

        def marshal_response(protocol_request, return_value)
          marshal = lambda do |signature|
            mapping = mapper.lookup(signature[0])
            return_value = fixup_array_types(mapping, return_value)
            signature = signature.map{|x|mapper.lookup(x).ruby_klass}
            protocol_request.check_parameter_types([return_value], signature)
            param_def = [['retval', 'return', mapping.registry_mapping]]
            [param_def, ruby_to_soap(return_value)]
          end
          signature = protocol_request.return_signature
          param_def = nil
          if signature
            param_def, return_value = marshal.call(signature)
          else
            if protocol_request.checked?
              param_def, return_value = nil, nil
            else
              param_def, return_value = marshal.call([return_value.class])
            end
          end
          qname = XSD::QName.new(mapper.custom_namespace,
                                 protocol_request.public_method_name)
          response = SOAP::RPC::SOAPMethodResponse.new(qname, param_def)
          response.retval = return_value unless return_value.nil?
          ProtocolResponse.new(self, create_response(response), 'text/xml')
        end

        def marshal_exception(exc)
          ProtocolResponse.new(self, create_exception_response(exc), 'text/xml')
        end

        private
          def self.extract_soap_action(request)
            return nil unless request.method == :post
            content_type = request.env['HTTP_CONTENT_TYPE'] || 'text/xml'
            return nil unless content_type
            soap_action = request.env['HTTP_SOAPACTION']
            return nil unless soap_action
            soap_action.gsub!(/^"/, '')
            soap_action.gsub!(/"$/, '')
            soap_action.strip!
            return nil if soap_action.empty?
            soap_action
          end

          def fixup_array_types(mapping, obj)
            mapping.each_attribute do |name, type, attr_mapping|
              if attr_mapping.custom_type?
                attr_obj = obj.send(name)
                new_obj = fixup_array_types(attr_mapping, attr_obj)
                obj.send("#{name}=", new_obj) unless new_obj.equal?(attr_obj)
              end
            end
            if mapping.is_a?(SoapArrayMapping)
              obj = mapping.ruby_klass.new(obj)
              # man, this is going to be slow for big arrays :(
              (1..obj.size).each do |i|
                i -= 1
                obj[i] = fixup_array_types(mapping.element_mapping, obj[i])
              end
            else
              if !mapping.generated_klass.nil? && mapping.generated_klass.respond_to?(:members)
                # have to map the publically visible structure of the class
                new_obj = mapping.generated_klass.new
                mapping.generated_klass.members.each do |name, klass|
                  new_obj.send("#{name}=", obj.send(name))
                end
                obj = new_obj
              end
            end
            obj
          end

          def map_signature_types(types)
            types.collect{|type| mapper.map(type)}
          end

          def create_response(body)
            header = SOAP::SOAPHeader.new
            body = SOAP::SOAPBody.new(body)
            envelope = SOAP::SOAPEnvelope.new(header, body)
            SOAP::Processor.marshal(envelope)
          end
  
          def create_exception_response(exc)
            detail = SOAP::Mapping::SOAPException.new(exc)
            body = SOAP::SOAPFault.new(
              SOAP::SOAPString.new('Server'),
              SOAP::SOAPString.new(exc.to_s),
              SOAP::SOAPString.new(self.class.name),
              SOAP::Mapping.obj2soap(detail))
            create_response(body)
          end

          def ruby_to_soap(obj)
            SOAP::Mapping.obj2soap(obj, mapper.registry)
          end

          def soap_to_ruby(obj)
            SOAP::Mapping.soap2obj(obj, mapper.registry)
          end

          def soap_to_ruby_array(array)
            array.map{|x| soap_to_ruby(x)}
          end
      end

      class SoapMapper # :nodoc:
        attr :registry
        attr :custom_namespace
        attr :custom_types

        def initialize(custom_namespace)
          @custom_namespace = custom_namespace
          @registry = SOAP::Mapping::Registry.new
          @klass2map = {}
          @custom_types = {}
          @ar2klass = {}
        end

        def lookup(klass)
          lookup_klass = klass.is_a?(Array) ? klass[0] : klass
          generated_klass = nil
          unless lookup_klass.respond_to?(:ancestors)
            raise(ProtocolError, "expected parameter type definition to be a Class")
          end
          if lookup_klass.ancestors.include?(ActiveRecord::Base)
            generated_klass = @ar2klass.has_key?(klass) ? @ar2klass[klass] : nil
            klass = generated_klass if generated_klass
          end
          return @klass2map[klass] if @klass2map.has_key?(klass)
  
          custom_type = false
  
          ruby_klass = select_class(lookup_klass)
          generated_klass = @ar2klass[lookup_klass] if @ar2klass.has_key?(lookup_klass)
          type_name = ruby_klass.name
  
          # Array signatures generate a double-mapping and require generation
          # of an Array subclass to represent the mapping in the SOAP
          # registry
          array_klass = nil
          if klass.is_a?(Array)
            array_klass = Class.new(Array) do
              module_eval <<-END
              def self.name
                "#{type_name}Array"
              end
              END
            end
          end
  
          mapping = @registry.find_mapped_soap_class(ruby_klass) rescue nil
          unless mapping
            # Custom structured type, generate a mapping
            info = { :type => XSD::QName.new(@custom_namespace, type_name) }
            @registry.add(ruby_klass,
                          SOAP::SOAPStruct, 
                          SOAP::Mapping::Registry::TypedStructFactory,
                          info)
            mapping = ensure_mapped(ruby_klass)
            custom_type = true
          end
  
          array_mapping = nil
          if array_klass
            # Typed array always requires a custom type. The info of the array
            # is the info of its element type (in mapping[2]), falling back
            # to SOAP base types.
            info = mapping[2]
            info ||= {}
            info[:type] ||= soap_base_type_qname(mapping[0])
            @registry.add(array_klass,
                          SOAP::SOAPArray,
                          SOAP::Mapping::Registry::TypedArrayFactory,
                          info)
            array_mapping = ensure_mapped(array_klass)
          end
  
          if array_mapping
            @klass2map[ruby_klass] = SoapMapping.new(self,
                                                     type_name,
                                                     ruby_klass,
                                                     generated_klass,
                                                     mapping[0],
                                                     mapping,
                                                     custom_type)
            @klass2map[klass] = SoapArrayMapping.new(self,
                                                     type_name,
                                                     array_klass,
                                                     array_mapping[0],
                                                     array_mapping,
                                                     @klass2map[ruby_klass])
            @custom_types[klass] = @klass2map[klass]
            @custom_types[ruby_klass] = @klass2map[ruby_klass] if custom_type
          else
            @klass2map[klass] = SoapMapping.new(self,
                                                type_name,
                                                ruby_klass,
                                                generated_klass,
                                                mapping[0],
                                                mapping,
                                                custom_type)
            @custom_types[klass] = @klass2map[klass] if custom_type
          end
  
          @klass2map[klass]
        end
        alias :map :lookup
        
        def map_container_services(container, &block)
          dispatching_mode = container.service_dispatching_mode
          services = nil
          case dispatching_mode
          when :direct
            api = container.class.service_api
            if container.respond_to?(:controller_class_name)
              service_name = container.controller_class_name.sub(/Controller$/, '').underscore
            else
              service_name = container.class.name.demodulize.underscore
            end
            services = { service_name => api }
          when :delegated
            services = {}
            container.class.services.each do |service_name, service_info|
              begin
                object = container.service_object(service_name)
              rescue Exception => e
                raise(ProtocolError, "failed to retrieve service object for mapping: #{e.message}")
              end
              services[service_name] = object.class.service_api
            end
          end
          services.each do |service_name, api|
            if api.nil?
              raise(ProtocolError, "no service API set while in :#{dispatching_mode} mode")
            end
            map_api(api) do |api_methods|
              yield service_name, api, api_methods if block_given?
            end
          end
        end

        def map_api(api, &block)
          lookup_proc = lambda do |klass|
            mapping = lookup(klass)
            custom_mapping = nil
            if mapping.respond_to?(:element_mapping)
              custom_mapping = mapping.element_mapping
            else
              custom_mapping = mapping
            end
            if custom_mapping && custom_mapping.custom_type?
              # What gives? This is required so that structure types
              # referenced only by structures (and not signatures) still
              # have a custom type mapping in the registry (needed for WSDL
              # generation).
              custom_mapping.each_attribute{}
            end
            mapping 
          end
          api_methods = block.nil?? nil : {}
          api.api_methods.each do |method_name, method_info|
            expects = method_info[:expects]
            expects_signature = nil
            if expects
              expects_signature = block ? [] : nil
              expects.each do |klass|
                lookup_klass = nil
                if klass.is_a?(Hash)
                  lookup_klass = lookup_proc.call(klass.values[0])
                  expects_signature << {klass.keys[0]=>lookup_klass} if block
                else
                  lookup_klass = lookup_proc.call(klass)
                  expects_signature << lookup_klass if block
                end
              end
            end
            returns = method_info[:returns]
            returns_signature = returns ? returns.map{|klass| lookup_proc.call(klass)} : nil
            if block
              api_methods[method_name] = {
                :expects => expects_signature,
                :returns => returns_signature
              }
            end
          end
          yield api_methods if block
        end

        private
          def select_class(klass)
            return Integer if klass == Fixnum
            if klass.ancestors.include?(ActiveRecord::Base)
              new_klass = Class.new(ActionService::Struct)
              new_klass.class_eval <<-EOS
                def self.name
                  "#{klass.name}"
                end
              EOS
              klass.columns.each do |column|
                next if column.klass.nil?
                new_klass.send(:member, column.name.to_sym, column.klass)
              end
              @ar2klass[klass] = new_klass
              return new_klass
            end
            klass
          end

          def ensure_mapped(klass)
            mapping = @registry.find_mapped_soap_class(klass) rescue nil
            raise(ProtocolError, "failed to register #{klass.name}") unless mapping
            mapping
          end

          def soap_base_type_qname(base_type)
            xsd_type = base_type.ancestors.find{|c| c.const_defined? 'Type'}
            xsd_type ? xsd_type.const_get('Type') : XSD::XSDAnySimpleType::Type
          end
      end

      class SoapMapping # :nodoc:
        attr :ruby_klass
        attr :generated_klass
        attr :soap_klass
        attr :registry_mapping
  
        def initialize(mapper, type_name, ruby_klass, generated_klass, soap_klass, registry_mapping,
                       custom_type=false)
          @mapper = mapper
          @type_name = type_name
          @ruby_klass = ruby_klass
          @generated_klass = generated_klass
          @soap_klass = soap_klass
          @registry_mapping = registry_mapping
          @custom_type = custom_type
        end
  
        def type_name
          @type_name
        end
  
        def custom_type?
          @custom_type
        end
  
        def qualified_type_name
          name = type_name
          if custom_type?
            "typens:#{name}"
          else
            xsd_type_for(@soap_klass)
          end
        end
  
        def each_attribute(&block)
          if @ruby_klass.respond_to?(:members)
            @ruby_klass.members.each do |name, klass|
              name = name.to_s
              mapping = @mapper.lookup(klass)
              yield name, mapping.qualified_type_name, mapping
            end
          end
        end

        def is_xsd_type?(klass)
          klass.ancestors.include?(XSD::NSDBase)
        end
  
        def xsd_type_for(klass)
          ns = XSD::NS.new
          ns.assign(XSD::Namespace, SOAP::XSDNamespaceTag)
          xsd_klass = klass.ancestors.find{|c| c.const_defined?('Type')}
          return ns.name(XSD::AnyTypeName) unless xsd_klass
          ns.name(xsd_klass.const_get('Type'))
        end
      end
  
      class SoapArrayMapping < SoapMapping # :nodoc:
        attr :element_mapping
  
        def initialize(mapper, type_name, ruby_klass, soap_klass, registry_mapping, element_mapping)
          super(mapper, type_name, ruby_klass, nil, soap_klass, registry_mapping, true)
          @element_mapping = element_mapping
        end
  
        def type_name
          super + "Array"
        end

        def each_attribute(&block); end
      end
    end
  end
end
