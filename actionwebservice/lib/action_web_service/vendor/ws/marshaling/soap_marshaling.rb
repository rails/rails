require 'soap/mapping'
require 'xsd/ns'

module WS
  module Marshaling
    SoapEncodingNS = 'http://schemas.xmlsoap.org/soap/encoding/'

    class SoapError < WSError
    end

    class SoapMarshaler < AbstractMarshaler
      attr :registry
      attr_accessor :type_namespace

      def initialize(type_namespace='')
        @type_namespace = type_namespace
        @registry = SOAP::Mapping::Registry.new
        @spec2binding = {}
      end

      def marshal(param)
        annotate_arrays(param.info.data, param.value)
        if param.value.is_a?(Exception)
          detail = SOAP::Mapping::SOAPException.new(param.value)
          soap_obj = SOAP::SOAPFault.new(
            SOAP::SOAPString.new('Server'),
            SOAP::SOAPString.new(param.value.to_s),
            SOAP::SOAPString.new(self.class.name),
            SOAP::Mapping.obj2soap(detail))
        else
          soap_obj = SOAP::Mapping.obj2soap(param.value, @registry)
        end
        SoapForeignObject.new(param, soap_obj)
      end

      def unmarshal(obj)
        param = obj.param
        soap_object = obj.soap_object
        soap_type = soap_object ? soap_object.type : nil
        value = soap_object ? SOAP::Mapping.soap2obj(soap_object, @registry) : nil
        param.value = value
        param.info.type = value.class
        mapping = @registry.find_mapped_soap_class(param.info.type) rescue nil
        if soap_type && soap_type.name == 'Array' && soap_type.namespace == SoapEncodingNS
          param.info.data = SoapBinding.new(self, soap_object.arytype, Array, mapping)
        else
          param.info.data = SoapBinding.new(self, soap_type, value.class, mapping)
        end
        param
      end

      def register_type(spec)
        if @spec2binding.has_key?(spec)
          return @spec2binding[spec]
        end

        klass = BaseTypes.canonical_param_type_class(spec)
        if klass.is_a?(Array)
          type_class = klass[0]
        else
          type_class = klass
        end

        type_binding = nil
        if (mapping = @registry.find_mapped_soap_class(type_class) rescue nil)
          qname = mapping[2] ? mapping[2][:type] : nil
          qname ||= soap_base_type_name(mapping[0])
          type_binding = SoapBinding.new(self, qname, type_class, mapping)
        else
          qname = XSD::QName.new(@type_namespace, soap_type_name(type_class.name))
          @registry.add(type_class,
                        SOAP::SOAPStruct,
                        typed_struct_factory(type_class),
                        { :type => qname })
          mapping = @registry.find_mapped_soap_class(type_class)
          type_binding = SoapBinding.new(self, qname, type_class, mapping)
        end
        
        array_binding = nil
        if klass.is_a?(Array)
          array_mapping = @registry.find_mapped_soap_class(Array) rescue nil
          if (array_mapping && !array_mapping[1].is_a?(SoapTypedArrayFactory)) || array_mapping.nil?
            @registry.set(Array,
                          SOAP::SOAPArray,
                          SoapTypedArrayFactory.new)
            array_mapping = @registry.find_mapped_soap_class(Array)
          end
          qname = XSD::QName.new(@type_namespace, soap_type_name(type_class.name) + 'Array')
          array_binding = SoapBinding.new(self, qname, Array, array_mapping, type_binding)
        end

        @spec2binding[spec] = array_binding ? array_binding : type_binding
        @spec2binding[spec]
      end

      protected
        def annotate_arrays(binding, value)
          if binding.is_typed_array?
            mark_typed_array(value, binding.element_binding.qname)
            if binding.element_binding.is_custom_type?
              value.each do |element|
                annotate_arrays(register_type(element.class), element)
              end
            end
          elsif binding.is_typed_struct?
            if binding.type_class.respond_to?(:members)
              binding.type_class.members.each do |name, spec|
                member_binding = register_type(spec)
                member_value = value.send(name)
                if member_binding.is_custom_type?
                  annotate_arrays(member_binding, member_value)
                end
              end
            end
          end
        end

        def mark_typed_array(array, qname)
          (class << array; self; end).class_eval do 
            define_method(:arytype) do
              qname
            end
          end
        end

        def typed_struct_factory(type_class)
          if Object.const_defined?('ActiveRecord')
            if WS.derived_from?(ActiveRecord::Base, type_class)
              qname =  XSD::QName.new(@type_namespace, soap_type_name(type_class.name))
              type_class.instance_variable_set('@qname', qname)
              return SoapActiveRecordStructFactory.new
            end
          end
          SOAP::Mapping::Registry::TypedStructFactory
        end

        def soap_type_name(type_name)
          type_name.gsub(/::/, '..')
        end

        def soap_base_type_name(type)
          xsd_type = type.ancestors.find{|c| c.const_defined? 'Type'}
          xsd_type ? xsd_type.const_get('Type') : XSD::XSDAnySimpleType::Type
        end
    end

    class SoapForeignObject
      attr_accessor :param
      attr_accessor :soap_object

      def initialize(param, soap_object)
        @param = param
        @soap_object = soap_object
      end
    end

    class SoapBinding
      attr :qname
      attr :type_class
      attr :mapping
      attr :element_binding

      def initialize(marshaler, qname, type_class, mapping, element_binding=nil)
        @marshaler = marshaler
        @qname = qname
        @type_class = type_class
        @mapping = mapping
        @element_binding = element_binding
      end

      def is_custom_type?
        is_typed_array? || is_typed_struct?
      end

      def is_typed_array?
        @mapping[1].is_a?(WS::Marshaling::SoapTypedArrayFactory)
      end

      def is_typed_struct?
        @mapping[1] == SOAP::Mapping::Registry::TypedStructFactory || \
        @mapping[1].is_a?(WS::Marshaling::SoapActiveRecordStructFactory)
      end

      def each_member(&block)
        if is_typed_struct?
          if @mapping[1] == SOAP::Mapping::Registry::TypedStructFactory
            if @type_class.respond_to?(:members)
              @type_class.members.each do |name, spec|
                yield name, spec
              end
            end
          elsif @mapping[1].is_a?(WS::Marshaling::SoapActiveRecordStructFactory)
            @type_class.columns.each do |column|
              yield column.name, column.klass
            end
          end
        end
      end

      def type_name
        is_custom_type? ? @qname.name : nil
      end

      def qualified_type_name(ns=nil)
        if is_custom_type?
          "#{ns ? ns : @qname.namespace}:#{@qname.name}"
        else
          ns = XSD::NS.new
          ns.assign(XSD::Namespace, SOAP::XSDNamespaceTag)
          xsd_klass = mapping[0].ancestors.find{|c| c.const_defined?('Type')}
          return ns.name(XSD::AnyTypeName) unless xsd_klass
          ns.name(xsd_klass.const_get('Type'))
        end
      end
    end

    class SoapActiveRecordStructFactory < SOAP::Mapping::Factory
      def obj2soap(soap_class, obj, info, map)
        unless obj.is_a?(ActiveRecord::Base)
          return nil
        end
        soap_obj = soap_class.new(obj.class.instance_variable_get('@qname'))
        obj.attributes.each do |key, value|
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

    module ActiveRecordSoapMarshallable
      def allocate
        obj = super
        attrs = {}
        self.columns.each{|c| attrs[c.name.to_s] = c.default}
        obj.instance_variable_set('@attributes', attrs)
        obj
      end
    end

    if Object.const_defined?('ActiveRecord')
      ActiveRecord::Base.extend(ActiveRecordSoapMarshallable)
    end
  end
end
