module WS
  module Encoding
    # Encoders operate on _foreign_ objects. That is, Ruby object
    # instances that are the _marshaling format specific_ representation
    # of objects. In other words, objects that have not yet been marshaled, but
    # are in protocol-specific form (such as an AST or DOM element), and not
    # native Ruby form.
    class AbstractEncoding
      def encode_rpc_call(method_name, params)
        raise NotImplementedError
      end

      def decode_rpc_call(obj)
        raise NotImplementedError
      end

      def encode_rpc_response(method_name, return_value)
        raise NotImplementedError
      end

      def decode_rpc_response(obj)
        raise NotImplementedError
      end
    end
  end
end
