module WS
  module Marshaling
    class AbstractMarshaler
      def marshal(param)
        raise NotImplementedError
      end

      def unmarshal(param)
        raise NotImplementedError
      end

      def register_type(type)
        nil
      end
    end
  end
end
