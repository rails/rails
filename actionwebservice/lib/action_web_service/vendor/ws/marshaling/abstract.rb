module WS
  module Marshaling
    class AbstractMarshaler
      def initialize
        @base_type_caster = BaseTypeCaster.new
      end

      def marshal(param)
        raise NotImplementedError
      end

      def unmarshal(param)
        raise NotImplementedError
      end

      def register_type(type)
        nil
      end
      alias :lookup_type :register_type

      def cast_inbound_recursive(value, spec)
        raise NotImplementedError
      end

      def cast_outbound_recursive(value, spec)
        raise NotImplementedError
      end

      attr :base_type_caster
      protected :base_type_caster
    end
  end
end
