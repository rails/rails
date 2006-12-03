require 'soap/mapping'

module ActionWebService
  module Protocol
    module Soap
      # Workaround for SOAP4R return values changing
      class Registry < SOAP::Mapping::Registry
        if SOAP::Version >= "1.5.4"
          def find_mapped_soap_class(obj_class)
            return @map.instance_eval { @obj2soap[obj_class][0] }
          end

          def find_mapped_obj_class(soap_class)
            return @map.instance_eval { @soap2obj[soap_class][0] }
          end
        end
      end

      class SoapMarshaler
        attr :namespace
        attr :registry

        def initialize(namespace=nil)
          @namespace = namespace || 'urn:ActionWebService'
          @registry = Registry.new
          @type2binding = {}
          register_static_factories
        end

        def soap_to_ruby(obj)
          SOAP::Mapping.soap2obj(obj, @registry)
        end

        def ruby_to_soap(obj)
          soap = SOAP::Mapping.obj2soap(obj, @registry)
          soap.elename = XSD::QName.new if SOAP::Version >= "1.5.5" && soap.elename == XSD::QName::EMPTY
          soap
        end

        def register_type(type)
          return @type2binding[type] if @type2binding.has_key?(type)

          if type.array?
            array_mapping = @registry.find_mapped_soap_class(Array)
            qname = XSD::QName.new(@namespace, soap_type_name(type.element_type.type_class.name) + 'Array')
            element_type_binding = register_type(type.element_type)
            @type2binding[type] = SoapBinding.new(self, qname, type, array_mapping, element_type_binding)
          elsif (mapping = @registry.find_mapped_soap_class(type.type_class) rescue nil)
            qname = mapping[2] ? mapping[2][:type] : nil
            qname ||= soap_base_type_name(mapping[0])
            @type2binding[type] = SoapBinding.new(self, qname, type, mapping)
          else
            qname = XSD::QName.new(@namespace, soap_type_name(type.type_class.name))
            @registry.add(type.type_class,
              SOAP::SOAPStruct,
              typed_struct_factory(type.type_class),
              { :type => qname })
            mapping = @registry.find_mapped_soap_class(type.type_class)
            @type2binding[type] = SoapBinding.new(self, qname, type, mapping)
          end

          if type.structured?
            type.each_member do |m_name, m_type|
              register_type(m_type)
            end
          end
          
          @type2binding[type]
        end
        alias :lookup_type :register_type

        def annotate_arrays(binding, value)
          if value.nil?
            return
          elsif binding.type.array?
            mark_typed_array(value, binding.element_binding.qname)
            if binding.element_binding.type.custom?
              value.each do |element|
                annotate_arrays(binding.element_binding, element)
              end
            end
          elsif binding.type.structured?
            binding.type.each_member do |name, type|
              member_binding = register_type(type)
              member_value = value.respond_to?('[]') ? value[name] : value.send(name)
              annotate_arrays(member_binding, member_value) if type.custom?
            end
          end
        end

        private
          def typed_struct_factory(type_class)
            if Object.const_defined?('ActiveRecord')
              if type_class.ancestors.include?(ActiveRecord::Base)
                qname =  XSD::QName.new(@namespace, soap_type_name(type_class.name))
                type_class.instance_variable_set('@qname', qname)
                return SoapActiveRecordStructFactory.new
              end
            end
            SOAP::Mapping::Registry::TypedStructFactory
          end

          def mark_typed_array(array, qname)
            (class << array; self; end).class_eval do 
              define_method(:arytype) do
                qname
              end
            end
          end

          def soap_base_type_name(type)
            xsd_type = type.ancestors.find{ |c| c.const_defined? 'Type' }
            xsd_type ? xsd_type.const_get('Type') : XSD::XSDAnySimpleType::Type
          end

          def soap_type_name(type_name)
            type_name.gsub(/::/, '..')
          end

          def register_static_factories
            @registry.add(ActionWebService::Base64, SOAP::SOAPBase64, SoapBase64Factory.new, nil)
            mapping = @registry.find_mapped_soap_class(ActionWebService::Base64)
            @type2binding[ActionWebService::Base64] =
              SoapBinding.new(self, SOAP::SOAPBase64::Type, ActionWebService::Base64, mapping)
            @registry.add(Array, SOAP::SOAPArray, SoapTypedArrayFactory.new, nil)
            @registry.add(::BigDecimal, SOAP::SOAPDouble, SOAP::Mapping::Registry::BasetypeFactory, {:derived_class => true})
          end
      end

      class SoapBinding
        attr :qname
        attr :type
        attr :mapping
        attr :element_binding

        def initialize(marshaler, qname, type, mapping, element_binding=nil)
          @marshaler = marshaler
          @qname = qname
          @type = type
          @mapping = mapping
          @element_binding = element_binding
        end

        def type_name
          @type.custom? ? @qname.name : nil
        end

        def qualified_type_name(ns=nil)
          if @type.custom?
            "#{ns ? ns : @qname.namespace}:#{@qname.name}"
          else
            ns = XSD::NS.new
            ns.assign(XSD::Namespace, SOAP::XSDNamespaceTag)
            ns.assign(SOAP::EncodingNamespace, "soapenc")
            xsd_klass = mapping[0].ancestors.find{|c| c.const_defined?('Type')}
            return ns.name(XSD::AnyTypeName) unless xsd_klass
            ns.name(xsd_klass.const_get('Type'))
          end
        end

        def eql?(other)
          @qname == other.qname
        end
        alias :== :eql?

        def hash
          @qname.hash
        end
      end

      class SoapActiveRecordStructFactory < SOAP::Mapping::Factory
        def obj2soap(soap_class, obj, info, map)
          unless obj.is_a?(ActiveRecord::Base)
            return nil
          end
          soap_obj = soap_class.new(obj.class.instance_variable_get('@qname'))
          obj.class.columns.each do |column|
            key = column.name.to_s
            value = obj.send(key)
            soap_obj[key] = SOAP::Mapping._obj2soap(value, map)
          end
          soap_obj
        end

        def soap2obj(obj_class, node, info, map)
          unless node.type == obj_class.instance_variable_get('@qname')
            return false
          end
          obj = obj_class.new
          node.each do |key, value|
            obj[key] = value.data
          end
          obj.instance_variable_set('@new_record', false)
          return true, obj
        end
      end

      class SoapTypedArrayFactory < SOAP::Mapping::Factory
        def obj2soap(soap_class, obj, info, map)
          unless obj.respond_to?(:arytype)
            return nil
          end
          soap_obj = soap_class.new(SOAP::ValueArrayName, 1, obj.arytype)
          mark_marshalled_obj(obj, soap_obj)
          obj.each do |item|
            child = SOAP::Mapping._obj2soap(item, map)
            soap_obj.add(child)
          end
          soap_obj
        end
      
        def soap2obj(obj_class, node, info, map)
          return false
        end
      end

      class SoapBase64Factory < SOAP::Mapping::Factory
        def obj2soap(soap_class, obj, info, map)
          unless obj.is_a?(ActionWebService::Base64)
            return nil
          end
          return soap_class.new(obj)
        end

        def soap2obj(obj_class, node, info, map)
          unless node.type == SOAP::SOAPBase64::Type
            return false
          end
          return true, obj_class.new(node.string)
        end
      end

    end
  end
end
