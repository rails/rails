module WS
  module Marshaling
    class XmlRpcError < WSError
    end

    class XmlRpcMarshaler < AbstractMarshaler
      def initialize
        super()
        @spec2binding = {}
      end

      def marshal(param)
        value = param.value
        cast_outbound_recursive(param.value, spec_for(param)) rescue value
      end

      def unmarshal(obj)
        obj.param
      end

      def typed_unmarshal(obj, spec)
        obj.param.info.data = lookup_type(spec)
        value = obj.param.value
        obj.param.value = cast_inbound_recursive(value, spec) rescue value
        obj.param
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
      alias :lookup_type :register_type

      def cast_inbound_recursive(value, spec)
        binding = lookup_type(spec)
        case binding
        when XmlRpcArrayBinding
          value.map{ |x| cast_inbound(x, binding.element_klass) }
        when XmlRpcBinding
          cast_inbound(value, binding.klass)
        end
      end

      def cast_outbound_recursive(value, spec)
        binding = lookup_type(spec)
        case binding
        when XmlRpcArrayBinding
          value.map{ |x| cast_outbound(x, binding.element_klass) }
        when XmlRpcBinding
          cast_outbound(value, binding.klass)
        end
      end

      private
        def spec_for(param)
          binding = param.info.data
          binding.is_a?(XmlRpcArrayBinding) ? [binding.element_klass] : binding.klass
        end

        def cast_inbound(value, klass)
          if BaseTypes.base_type?(klass)
            value = value.to_time if value.is_a?(XMLRPC::DateTime)
            base_type_caster.cast(value, klass)
          elsif value.is_a?(XMLRPC::FaultException)
            value
          elsif klass.ancestors.include?(ActionWebService::Struct)
            obj = klass.new
            klass.members.each do |name, klass|
              name = name.to_s
              obj.send('%s=' % name, cast_inbound_recursive(value[name], klass))
            end
            obj
          else
            obj = klass.new
            if obj.respond_to?(:update)
              obj.update(value)
            else
              value.each do |name, val|
                obj.send('%s=' % name.to_s, val)
              end
            end
            obj
          end
        end

        def cast_outbound(value, klass)
          if BaseTypes.base_type?(klass)
            base_type_caster.cast(value, klass)
          elsif value.is_a?(Exception)
            XMLRPC::FaultException.new(2, value.message)
          elsif Object.const_defined?('ActiveRecord') && value.is_a?(ActiveRecord::Base)
            value.attributes
          elsif value.is_a?(ActionWebService::Struct)
            struct = {}
            value.class.members.each do |name, klass|
              name = name.to_s
              struct[name] = cast_outbound_recursive(value[name], klass)
            end
            struct
          else
            struct = {}
            if value.respond_to?(:each_pair)
              value.each_pair{ |key, value| struct[key] = value }
            else
              value.instance_variables.each do |name|
                key = name.sub(/^@/, '')
                struct[key] = value.instance_variable_get(name)
              end
            end
            struct
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
