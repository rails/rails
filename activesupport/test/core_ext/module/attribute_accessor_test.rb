require 'abstract_unit'

class ModuleAttributeAccessorTest < Test::Unit::TestCase
  def setup
    m = @module = Module.new do
      mattr_accessor :foo
      mattr_accessor :bar,  :instance_writer => false
      mattr_reader   :shaq, :instance_reader => false
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
    assert @module.respond_to?(:foo)
    assert @module.respond_to?(:foo=)
    assert @object.respond_to?(:bar)
    assert !@object.respond_to?(:bar=)
  end

  def test_should_not_create_instance_reader
    assert @module.respond_to?(:shaq)
    assert !@object.respond_to?(:shaq)
  end
end
