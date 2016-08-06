require "abstract_unit"
require "active_support/core_ext/module/attribute_accessors"

class ModuleAttributeAccessorTest < ActiveSupport::TestCase
  def setup
    m = @module = Module.new do
      mattr_accessor :foo
      mattr_accessor :bar, :instance_writer => false
      mattr_reader   :shaq, :instance_reader => false
      mattr_accessor :camp, :instance_accessor => false

      cattr_accessor(:defa) { "default_accessor_value" }
      cattr_reader(:defr) { "default_reader_value" }
      cattr_writer(:defw) { "default_writer_value" }
      cattr_accessor(:quux) { :quux }
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

  def test_cattr_accessor_default_value
    assert_equal :quux, @module.quux
    assert_equal :quux, @object.quux
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
    exception = assert_raises NameError do
      Class.new do
        cattr_reader "1nvalid"
      end
    end
    assert_equal "invalid attribute name: 1nvalid", exception.message

    exception = assert_raises NameError do
      Class.new do
        cattr_writer "1nvalid"
      end
    end
    assert_equal "invalid attribute name: 1nvalid", exception.message

    exception = assert_raises NameError do
      Class.new do
        mattr_reader "valid_part\ninvalid_part"
      end
    end
    assert_equal "invalid attribute name: valid_part\ninvalid_part", exception.message

    exception = assert_raises NameError do
      Class.new do
        mattr_writer "valid_part\ninvalid_part"
      end
    end
    assert_equal "invalid attribute name: valid_part\ninvalid_part", exception.message
  end

  def test_should_use_default_value_if_block_passed
    assert_equal "default_accessor_value", @module.defa
    assert_equal "default_reader_value", @module.defr
    assert_equal "default_writer_value", @module.class_variable_get("@@defw")
  end

  def test_should_not_invoke_default_value_block_multiple_times
    count = 0
    @module.cattr_accessor(:defcount){ count += 1 }
    assert_equal 1, count
  end
end
