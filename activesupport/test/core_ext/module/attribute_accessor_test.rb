require 'abstract_unit'
require 'active_support/core_ext/module/attribute_accessors'

class ModuleAttributeAccessorTest < ActiveSupport::TestCase
  def setup
    m = @module = Module.new do
      mattr_accessor :foo
      mattr_accessor :bar, :instance_writer => false
      mattr_reader   :shaq, :instance_reader => false
      mattr_accessor :camp, :instance_accessor => false
    end
    @class = Class.new
    @class.instance_eval { include m }
    @object = @class.new
  end

  def test_should_use_mattr_default
    assert_nil @module.foo
    assert_nil @object.foo
  end

  def test_should_set_mattr_value
    @module.foo = :test
    assert_equal :test, @object.foo

    @object.foo = :test2
    assert_equal :test2, @module.foo
  end

  def test_should_not_create_instance_writer
    assert_respond_to @module, :foo
    assert_respond_to @module, :foo=
    assert_respond_to @object, :bar
    assert !@object.respond_to?(:bar=)
  end

  def test_should_not_create_instance_reader
    assert_respond_to @module, :shaq
    assert !@object.respond_to?(:shaq)
  end

  def test_should_not_create_instance_accessors
    assert_respond_to @module, :camp
    assert !@object.respond_to?(:camp)
    assert !@object.respond_to?(:camp=)
  end

  def test_should_raise_name_error_if_attribute_name_is_invalid
    assert_raises NameError do
      Class.new do
        mattr_reader "invalid attribute name"
      end
    end

    assert_raises NameError do
      Class.new do
        mattr_writer "invalid attribute name"
      end
    end
  end
end
