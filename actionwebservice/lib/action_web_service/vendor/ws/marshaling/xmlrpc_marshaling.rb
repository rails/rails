module WS
  module Marshaling
    class XmlRpcError < WSError
    end

    class XmlRpcMarshaler < AbstractMarshaler
      def initialize
        @caster = BaseTypeCaster.new
        @spec2binding = {}
      end

      def marshal(param)
        transform_outbound(param)
      end

      def unmarshal(obj)
        obj.param.value = transform_inbound(obj.param)
        obj.param
      end

      def typed_unmarshal(obj, spec)
        param = obj.param
        param.info.data = register_type(spec)
        param.value = transform_inbound(param)
        param
      end

      def register_type(spec)
        if @spec2binding.has_key?(spec)
          return @spec2binding[spec]
        end

        klass = BaseTypes.canonical_param_type_class(spec)
        type_binding = nil
        if klass.is_a?(Array)
          type_binding = XmlRpcArrayBinding.new(klass[0])
        else
          type_binding = XmlRpcBinding.new(klass)
        end

        @spec2binding[spec] = type_binding
      end

      def transform_outbound(param)
        binding = param.info.data
        case binding
        when XmlRpcArrayBinding
          param.value.map{|x| cast_outbound(x, binding.element_klass)}
        when XmlRpcBinding
          cast_outbound(param.value, param.info.type)
        end
      end

      def transform_inbound(param)
        return param.value if param.info.data.nil?
        binding = param.info.data
        param.info.type = binding.klass
        case binding
        when XmlRpcArrayBinding
          param.value.map{|x| cast_inbound(x, binding.element_klass)}
        when XmlRpcBinding
          cast_inbound(param.value, param.info.type)
        end
      end

      def cast_outbound(value, klass)
        if BaseTypes.base_type?(klass)
          @caster.cast(value, klass)
        elsif value.is_a?(Exception)
          XMLRPC::FaultException.new(2, value.message)
        elsif Object.const_defined?('ActiveRecord') && value.is_a?(ActiveRecord::Base)
          value.attributes
        else
          struct = {}
          value.instance_variables.each do |name|
            key = name.sub(/^@/, '')
            struct[key] = value.instance_variable_get(name)
          end
          struct
        end
      end

      def cast_inbound(value, klass)
        if BaseTypes.base_type?(klass)
          value = value.to_time if value.is_a?(XMLRPC::DateTime)
          @caster.cast(value, klass)
        elsif value.is_a?(XMLRPC::FaultException)
          value
        else
          obj = klass.new
          value.each do |name, val|
            obj.send('%s=' % name.to_s, val)
          end
          obj
        end
      end
    end

    class XmlRpcBinding
      attr :klass
      
      def initialize(klass)
        @klass = klass
      end
    end

    class XmlRpcArrayBinding < XmlRpcBinding
      attr :element_klass

      def initialize(element_klass)
        super(Array)
        @element_klass = element_klass
      end
    end
  end
end
