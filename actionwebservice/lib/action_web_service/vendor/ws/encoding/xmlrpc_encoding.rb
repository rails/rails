require 'xmlrpc/marshal'

module WS
  module Encoding
    class XmlRpcEncoding < AbstractEncoding
      def encode_rpc_call(method_name, params)
        XMLRPC::Marshal.dump_call(method_name, *params)
      end

      def decode_rpc_call(obj)
        method_name, params = XMLRPC::Marshal.load_call(obj)
        i = 0
        params = params.map do |value|
          param = XmlRpcDecodedParam.new("param#{i}", value)
          i += 1
          param
        end
        [method_name, params]
      end

      def encode_rpc_response(method_name, return_value)
        if return_value.nil?
          XMLRPC::Marshal.dump_response(true)
        else
          XMLRPC::Marshal.dump_response(return_value)
        end
      end

      def decode_rpc_response(obj)
        return_value = XMLRPC::Marshal.load_response(obj)
        [nil, XmlRpcDecodedParam.new('return', return_value)]
      end
    end

    class XmlRpcDecodedParam
      attr :param

      def initialize(name, value)
        info = ParamInfo.new(name, value.class)
        @param = Param.new(value, info)
      end
    end
  end
end
