require File.dirname(__FILE__) + '/abstract_unit'

module Nested
  class StructClass
    attr_accessor :name
    attr_accessor :version

    def initialize
      @name = 5
      @version = "1.0"
    end

    def ==(other)
      @name == other.name && @version == other.version
    end
  end
end

module EncodingTest
  def setup
    @call_signature = [:int, :bool, :string, :float, [:time], Nested::StructClass]
    @call_params = [1, true, "string", 5.0, [Time.now], Nested::StructClass.new]
    @response_signature = [:string]
    @response_param = "hello world"
    test_setup
  end

  def test_abstract
    obj = WS::Encoding::AbstractEncoding.new
    assert_raises(NotImplementedError) do
      obj.encode_rpc_call(nil, nil)
    end
    assert_raises(NotImplementedError) do
      obj.decode_rpc_call(nil)
    end
    assert_raises(NotImplementedError) do
      obj.encode_rpc_response(nil, nil)
    end
    assert_raises(NotImplementedError) do
      obj.decode_rpc_response(nil)
    end
  end

  def encode_rpc_call(method_name, signature, params)
    params = params.dup
    (0..(signature.length-1)).each do |i|
      type_binding = @marshaler.register_type(signature[i])
      info = WS::ParamInfo.create(signature[i], type_binding, i)
      params[i] = @marshaler.marshal(WS::Param.new(params[i], info))
    end
    @encoder.encode_rpc_call(method_name, params)
  end

  def decode_rpc_call(obj)
    @encoder.decode_rpc_call(obj)
  end

  def encode_rpc_response(method_name, signature, param)
    type_binding = @marshaler.register_type(signature[0])
    info = WS::ParamInfo.create(signature[0], type_binding, 0)
    param = @marshaler.marshal(WS::Param.new(param, info))
    @encoder.encode_rpc_response(method_name, param)
  end

  def decode_rpc_response(obj)
    @encoder.decode_rpc_response(obj)
  end
end
