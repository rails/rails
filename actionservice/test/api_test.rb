require File.dirname(__FILE__) + '/abstract_unit'

module APITest
  class API < ActionService::API::Base
    api_method :void
    api_method :expects_and_returns, :expects_and_returns => [:string]
    api_method :expects,             :expects => [:int, :bool]
    api_method :returns,             :returns => [:int, [:string]]
    api_method :named_signature,     :expects => [{:appkey=>:int}, {:publish=>:bool}]
    api_method :string_types,        :expects => ['int', 'string', 'bool']
    api_method :class_types,         :expects => [TrueClass, Bignum, String]
  end
end

class TC_API < Test::Unit::TestCase
  API = APITest::API

  def test_api_method_declaration
    %w(
      void
      expects_and_returns
      expects
      returns
      named_signature
      string_types
      class_types
    ).each do |name|
      name = name.to_sym
      public_name = API.public_api_method_name(name)
      assert(API.has_api_method?(name))
      assert(API.has_public_api_method?(public_name))
      assert(API.api_method_name(public_name) == name)
      assert(API.api_methods.has_key?(name))
    end
  end

  def test_signature_canonicalization
    assert_equal({:expects=>nil, :returns=>nil}, API.api_methods[:void])
    assert_equal({:expects=>[String], :returns=>[String]}, API.api_methods[:expects_and_returns])
    assert_equal({:expects=>[Integer, TrueClass], :returns=>nil}, API.api_methods[:expects])
    assert_equal({:expects=>nil, :returns=>[Integer, [String]]}, API.api_methods[:returns])
    assert_equal({:expects=>[{:appkey=>Integer}, {:publish=>TrueClass}], :returns=>nil}, API.api_methods[:named_signature])
    assert_equal({:expects=>[Integer, String, TrueClass], :returns=>nil}, API.api_methods[:string_types])
    assert_equal({:expects=>[TrueClass, Bignum, String], :returns=>nil}, API.api_methods[:class_types])
  end

  def test_not_instantiable
    assert_raises(NoMethodError) do
      API.new
    end
  end
end
