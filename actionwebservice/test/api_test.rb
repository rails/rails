require File.dirname(__FILE__) + '/abstract_unit'

module APITest
  class API < ActionWebService::API::Base
    api_method :void
    api_method :expects_and_returns, :expects_and_returns => [:string]
    api_method :expects,             :expects => [:int, :bool]
    api_method :returns,             :returns => [:int, [:string]]
    api_method :named_signature,     :expects => [{:appkey=>:int}, {:publish=>:bool}]
    api_method :string_types,        :expects => ['int', 'string', 'bool', 'base64']
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
    assert_equal(nil, API.api_methods[:void].expects)
    assert_equal(nil, API.api_methods[:void].returns)
    assert_equal([String], API.api_methods[:expects_and_returns].expects.map{|x| x.type_class})
    assert_equal([String], API.api_methods[:expects_and_returns].returns.map{|x| x.type_class})
    assert_equal([Integer, TrueClass], API.api_methods[:expects].expects.map{|x| x.type_class})
    assert_equal(nil, API.api_methods[:expects].returns)
    assert_equal(nil, API.api_methods[:returns].expects)
    assert_equal([Integer, [String]], API.api_methods[:returns].returns.map{|x| x.array?? [x.element_type.type_class] : x.type_class})
    assert_equal([[:appkey, Integer], [:publish, TrueClass]], API.api_methods[:named_signature].expects.map{|x| [x.name, x.type_class]})
    assert_equal(nil, API.api_methods[:named_signature].returns)
    assert_equal([Integer, String, TrueClass, ActionWebService::Base64], API.api_methods[:string_types].expects.map{|x| x.type_class})
    assert_equal(nil, API.api_methods[:string_types].returns)
    assert_equal([TrueClass, Integer, String], API.api_methods[:class_types].expects.map{|x| x.type_class})
    assert_equal(nil, API.api_methods[:class_types].returns)
  end

  def test_not_instantiable
    assert_raises(NoMethodError) do
      API.new
    end
  end

  def test_api_errors
    assert_raises(ActionWebService::ActionWebServiceError) do
      klass = Class.new(ActionWebService::API::Base) do
        api_method :test, :expects => [ActiveRecord::Base]
      end
    end
    klass = Class.new(ActionWebService::API::Base) do
      allow_active_record_expects true
      api_method :test2, :expects => [ActiveRecord::Base]
    end
    assert_raises(ActionWebService::ActionWebServiceError) do
      klass = Class.new(ActionWebService::API::Base) do
        api_method :test, :invalid => [:int]
      end
    end
  end

  def test_parameter_names
    method = API.api_methods[:named_signature]
    assert_equal 0, method.expects_index_of(:appkey)
    assert_equal 1, method.expects_index_of(:publish)
    assert_equal 1, method.expects_index_of('publish')
    assert_equal 0, method.expects_index_of('appkey')
    assert_equal -1, method.expects_index_of('blah')
    assert_equal -1, method.expects_index_of(:missing)
    assert_equal -1, API.api_methods[:void].expects_index_of('test')
  end

  def test_parameter_hash
    method = API.api_methods[:named_signature]
    hash = method.expects_to_hash([5, false])
    assert_equal({:appkey => 5, :publish => false}, hash)
  end

  def test_api_methods_compat
    sig = API.api_methods[:named_signature][:expects]
    assert_equal [{:appkey=>Integer}, {:publish=>TrueClass}], sig
  end

  def test_to_s
    assert_equal 'void Expects(int param0, bool param1)', APITest::API.api_methods[:expects].to_s
  end
end
