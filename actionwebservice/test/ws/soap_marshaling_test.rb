require File.dirname(__FILE__) + '/abstract_unit'

module Nested
  class MyClass
    attr_accessor :id
    attr_accessor :name

    def initialize(id, name)
      @id = id
      @name = name
    end

    def ==(other)
      @id == other.id && @name == other.name
    end
  end
end

class SoapMarshalingTest < Test::Unit::TestCase
  def setup
    @marshaler = WS::Marshaling::SoapMarshaler.new
  end

  def test_abstract
    marshaler = WS::Marshaling::AbstractMarshaler.new
    assert_raises(NotImplementedError) do
      marshaler.marshal(nil)
    end
    assert_raises(NotImplementedError) do
      marshaler.unmarshal(nil)
    end
    assert_equal(nil, marshaler.register_type(nil))
    assert_raises(NotImplementedError) do
      marshaler.cast_inbound_recursive(nil, nil)
    end
    assert_raises(NotImplementedError) do
      marshaler.cast_outbound_recursive(nil, nil)
    end
  end

  def test_marshaling
    info = WS::ParamInfo.create(Nested::MyClass, @marshaler.register_type(Nested::MyClass))
    param = WS::Param.new(Nested::MyClass.new(2, "name"), info)
    new_param = @marshaler.unmarshal(@marshaler.marshal(param))
    assert(param == new_param)
  end
  
  def test_exception_marshaling
    info = WS::ParamInfo.create(RuntimeError, @marshaler.register_type(RuntimeError))
    param = WS::Param.new(RuntimeError.new("hello, world"), info)
    new_param = @marshaler.unmarshal(@marshaler.marshal(param))
    assert_equal("hello, world", new_param.value.detail.cause.message)
  end

  def test_registration
    type_binding1 = @marshaler.register_type(:int)
    type_binding2 = @marshaler.register_type(:int)
    assert(type_binding1.equal?(type_binding2))
  end

  def test_active_record
    if Object.const_defined?('ActiveRecord')
      node_class = Class.new(ActiveRecord::Base) do
        def initialize(*args)
          super(*args)
          @new_record = false
        end

        class << self
          def name
            "Node"
          end

          def columns(*args)
            [
              ActiveRecord::ConnectionAdapters::Column.new('id', 0, 'int'),
              ActiveRecord::ConnectionAdapters::Column.new('name', nil, 'string'),
              ActiveRecord::ConnectionAdapters::Column.new('email', nil, 'string'),
            ]
          end

          def connection
            self
          end
        end
      end
      info = WS::ParamInfo.create(node_class, @marshaler.register_type(node_class), 0)
      ar_obj = node_class.new('name' => 'hello', 'email' => 'test@test.com') 
      param = WS::Param.new(ar_obj, info)
      obj = @marshaler.marshal(param)
      param = @marshaler.unmarshal(obj)
      new_ar_obj = param.value
      assert_equal(ar_obj, new_ar_obj)
      assert(!ar_obj.equal?(new_ar_obj))
    end
  end
end
