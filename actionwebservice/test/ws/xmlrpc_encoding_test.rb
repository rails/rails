require File.dirname(__FILE__) + '/abstract_encoding'
require 'time'

class XmlRpcEncodingTest < Test::Unit::TestCase
  include EncodingTest

  def test_setup
    @encoder = WS::Encoding::XmlRpcEncoding.new
    @marshaler = WS::Marshaling::XmlRpcMarshaler.new
  end

  def test_typed_call_encoding_and_decoding
    obj = encode_rpc_call('DecodeMe', @call_signature, @call_params)
    method_name, params = decode_rpc_call(obj)
    (0..(@call_signature.length-1)).each do |i|
      params[i] = @marshaler.typed_unmarshal(params[i], @call_signature[i]).value
    end
    assert_equal(method_name, 'DecodeMe')
    assert_equal(@call_params[0..3], params[0..3])
    assert_equal(@call_params[5..-1], params[5..-1])
  end

  def test_untyped_call_encoding_and_decoding
    obj = encode_rpc_call('DecodeMe', @call_signature, @call_params)
    method_name, params = decode_rpc_call(obj)
    (0..(@call_signature.length-1)).each do |i|
      params[i] = @marshaler.unmarshal(params[i]).value
    end
    assert_equal(method_name, 'DecodeMe')
    assert_equal(@call_params[0..3], params[0..3])
    assert_equal(@call_params[5].name, params[5]['name'])
    assert_equal(@call_params[5].version, params[5]['version'])
  end
end
