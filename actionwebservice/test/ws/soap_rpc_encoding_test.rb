require File.dirname(__FILE__) + '/abstract_encoding'
require 'time'

class SoapRpcEncodingTest < Test::Unit::TestCase
  include EncodingTest

  def test_setup
    @encoder = WS::Encoding::SoapRpcEncoding.new
    @marshaler = WS::Marshaling::SoapMarshaler.new
  end

  def test_call_encoding_and_decoding
    obj = encode_rpc_call('DecodeMe', @call_signature, @call_params)
    method_name, decoded_params = decode_rpc_call(obj)
    params = decoded_params.map{|x| @marshaler.unmarshal(x).value}
    assert_equal(method_name, 'DecodeMe')
    assert_equal(@call_params[0..3], params[0..3])
    # XXX: DateTime not marshaled correctly yet
    assert_equal(@call_params[5..-1], params[5..-1])
  end

  def test_response_encoding_and_decoding_simple
    obj = encode_rpc_response('DecodeMe', @response_signature, @response_param)
    method_name, return_value = decode_rpc_response(obj)
    return_value = @marshaler.unmarshal(return_value).value
    assert_equal('DecodeMe', method_name)
    assert_equal(@response_param, return_value)
  end

  def test_response_encoding_and_decoding_struct
    struct = Nested::StructClass.new
    obj = encode_rpc_response('DecodeMe', [Nested::StructClass], struct)
    method_name, return_value = decode_rpc_response(obj)
    return_value = @marshaler.unmarshal(return_value).value
    assert_equal('DecodeMe', method_name)
    assert_equal(struct, return_value)
  end

  def test_response_encoding_and_decoding_array
    struct = Nested::StructClass.new
    obj = encode_rpc_response('DecodeMe', [[Nested::StructClass]], [struct])
    method_name, return_value = decode_rpc_response(obj)
    return_value = @marshaler.unmarshal(return_value).value
    assert_equal('DecodeMe', method_name)
    assert_equal([struct], return_value)
  end
end
