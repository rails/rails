# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/module/attribute_accessors_per_thread"

class ModuleAttributeAccessorPerThreadTest < ActiveSupport::TestCase
  setup do
    @class = Class.new do
      thread_mattr_accessor :foo
      thread_mattr_accessor :bar,  instance_writer: false
      thread_mattr_reader   :shaq, instance_reader: false
      thread_mattr_accessor :camp, instance_accessor: false
    end

    @subclass = Class.new(@class)

    @object = @class.new
  end

  def test_is_shared_between_fibers
    @class.foo = 42
    enumerator = Enumerator.new do |yielder|
      yielder.yield @class.foo
    end
    assert_equal 42, enumerator.next
  end

  def test_is_not_shared_between_fibers_if_isolation_level_is_fiber
    previous_level = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = :fiber

    @class.foo = 42
    enumerator = Enumerator.new do |yielder|
      yielder.yield @class.foo
    end
    assert_nil enumerator.next
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous_level
  end

  def test_default_value
    @class.thread_mattr_accessor :baz, default: "default_value"

    assert_equal "default_value", @class.baz
  end

  def test_default_value_is_accessible_from_subclasses
    @class.thread_mattr_accessor :baz, default: "default_value"

    assert_equal "default_value", @subclass.baz
  end

  def test_default_value_is_accessible_from_other_threads
    @class.thread_mattr_accessor :baz, default: "default_value"

    Thread.new do
      assert_equal "default_value", @class.baz
    end.join
  end

  def test_default_value_is_the_same_object
    default = Object.new
    @class.thread_mattr_accessor :baz, default: default

    assert_same default, @class.baz

    Thread.new do
      assert_same default, @class.baz
    end.join
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
      Thread.pass
      assert_equal "things", @class.foo
    end

    threads << Thread.new do
      @class.foo = "other things"
      Thread.pass
      assert_equal "other things", @class.foo
    end

    threads << Thread.new do
      @class.foo = "really other things"
      Thread.pass
      assert_equal "really other things", @class.foo
    end

    threads.each(&:join)
  end

  def test_should_raise_name_error_if_attribute_name_is_invalid
    exception = assert_raises NameError do
      Class.new do
        thread_cattr_reader "1nvalid"
      end
    end
    assert_match "invalid attribute name: 1nvalid", exception.message

    exception = assert_raises NameError do
      Class.new do
        thread_cattr_writer "1nvalid"
      end
    end
    assert_match "invalid attribute name: 1nvalid", exception.message

    exception = assert_raises NameError do
      Class.new do
        thread_mattr_reader "1valid_part"
      end
    end
    assert_match "invalid attribute name: 1valid_part", exception.message

    exception = assert_raises NameError do
      Class.new do
        thread_mattr_writer "2valid_part"
      end
    end
    assert_match "invalid attribute name: 2valid_part", exception.message
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

  def test_superclass_keeps_default_value_when_value_set_on_subclass
    @class.thread_mattr_accessor :baz, default: "default_value"
    @subclass.baz = "sub"

    assert_equal "default_value", @class.baz
    assert_equal "sub", @subclass.baz
  end

  def test_subclass_keeps_default_value_when_value_set_on_superclass
    @class.thread_mattr_accessor :baz, default: "default_value"
    @class.baz = "super"

    assert_equal "super", @class.baz
    assert_equal "default_value", @subclass.baz
  end

  def test_subclass_can_override_default_value_without_affecting_superclass
    @class.thread_mattr_accessor :baz, default: "super"
    @subclass.thread_mattr_accessor :baz, default: "sub"

    assert_equal "super", @class.baz
    assert_equal "sub", @subclass.baz
  end
end
