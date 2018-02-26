# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/module/attribute_accessors_per_thread"

class ModuleAttributeAccessorPerThreadTest < ActiveSupport::TestCase
  def setup
    @class = Class.new do
      thread_mattr_accessor :foo
      thread_mattr_accessor :bar,  instance_writer: false
      thread_mattr_reader   :shaq, instance_reader: false
      thread_mattr_accessor :camp, instance_accessor: false

      def self.name; "MyClass" end
    end

    @subclass = Class.new(@class) do
      def self.name; "SubMyClass" end
    end

    @object = @class.new
  end

  def test_should_use_mattr_default
    Thread.new do
      assert_nil @class.foo
      assert_nil @object.foo
    end.join
  end

  def test_should_set_mattr_value
    Thread.new do
      @class.foo = :test
      assert_equal :test, @class.foo

      @class.foo = :test2
      assert_equal :test2, @class.foo
    end.join
  end

  def test_should_not_create_instance_writer
    Thread.new do
      assert_respond_to @class, :foo
      assert_respond_to @class, :foo=
      assert_respond_to @object, :bar
      assert_not_respond_to @object, :bar=
    end.join
  end

  def test_should_not_create_instance_reader
    Thread.new do
      assert_respond_to @class, :shaq
      assert_not_respond_to @object, :shaq
    end.join
  end

  def test_should_not_create_instance_accessors
    Thread.new do
      assert_respond_to @class, :camp
      assert_not_respond_to @object, :camp
      assert_not_respond_to @object, :camp=
    end.join
  end

  def test_values_should_not_bleed_between_threads
    threads = []
    threads << Thread.new do
      @class.foo = "things"
      sleep 1
      assert_equal "things", @class.foo
    end

    threads << Thread.new do
      @class.foo = "other things"
      sleep 1
      assert_equal "other things", @class.foo
    end

    threads << Thread.new do
      @class.foo = "really other things"
      sleep 1
      assert_equal "really other things", @class.foo
    end

    threads.each { |t| t.join }
  end

  def test_should_raise_name_error_if_attribute_name_is_invalid
    exception = assert_raises NameError do
      Class.new do
        thread_cattr_reader "1nvalid"
      end
    end
    assert_equal "invalid attribute name: 1nvalid", exception.message

    exception = assert_raises NameError do
      Class.new do
        thread_cattr_writer "1nvalid"
      end
    end
    assert_equal "invalid attribute name: 1nvalid", exception.message

    exception = assert_raises NameError do
      Class.new do
        thread_mattr_reader "1valid_part"
      end
    end
    assert_equal "invalid attribute name: 1valid_part", exception.message

    exception = assert_raises NameError do
      Class.new do
        thread_mattr_writer "2valid_part"
      end
    end
    assert_equal "invalid attribute name: 2valid_part", exception.message
  end

  def test_should_return_same_value_by_class_or_instance_accessor
    @class.foo = "fries"

    assert_equal @class.foo, @object.foo
  end

  def test_should_not_affect_superclass_if_subclass_set_value
    @class.foo = "super"
    assert_equal "super", @class.foo
    assert_nil @subclass.foo

    @subclass.foo = "sub"
    assert_equal "super", @class.foo
    assert_equal "sub", @subclass.foo
  end
end
