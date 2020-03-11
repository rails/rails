# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/module/attribute_accessors"

class ModuleAttributeAccessorTest < ActiveSupport::TestCase
  def setup
    m = @module = Module.new do
      mattr_accessor :foo
      mattr_accessor :bar, instance_writer: false
      mattr_reader   :shaq, instance_reader: false
      mattr_accessor :camp, instance_accessor: false

      cattr_accessor(:defa) { "default_accessor_value" }
      cattr_reader(:defr) { "default_reader_value" }
      cattr_writer(:defw) { "default_writer_value" }
      cattr_accessor(:deff) { false }
      cattr_accessor(:quux) { :quux }

      cattr_accessor :def_accessor, default: "default_accessor_value"
      cattr_reader :def_reader, default: "default_reader_value"
      cattr_writer :def_writer, default: "default_writer_value"
      cattr_accessor :def_false, default: false
      cattr_accessor(:def_priority, default: false) { :no_priority }
    end
    @class = Class.new
    @class.instance_eval { include m }
    @object = @class.new
  end

  def test_should_use_mattr_default
    assert_nil @module.foo
    assert_nil @object.foo
  end

  def test_mattr_default_keyword_arguments
    assert_equal "default_accessor_value", @module.def_accessor
    assert_equal "default_reader_value", @module.def_reader
    assert_equal "default_writer_value", @module.class_variable_get(:@@def_writer)
  end

  def test_mattr_can_default_to_false
    assert_equal false, @module.def_false
    assert_equal false, @module.deff
  end

  def test_mattr_default_priority
    assert_equal false, @module.def_priority
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
    assert_not_respond_to @object, :bar=
  end

  def test_should_not_create_instance_reader
    assert_respond_to @module, :shaq
    assert_not_respond_to @object, :shaq
  end

  def test_should_not_create_instance_accessors
    assert_respond_to @module, :camp
    assert_not_respond_to @object, :camp
    assert_not_respond_to @object, :camp=
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

  def test_method_invocation_should_not_invoke_the_default_block
    count = 0

    @module.cattr_accessor(:defcount) { count += 1 }

    assert_equal 1, count
    assert_no_difference "count" do
      @module.defcount
    end
  end

  def test_declaring_multiple_attributes_at_once_invokes_the_block_multiple_times
    count = 0

    @module.cattr_accessor(:defn1, :defn2) { count += 1 }

    assert_equal 1, @module.defn1
    assert_equal 2, @module.defn2
  end

  def test_declaring_attributes_on_singleton_errors
    klass = Class.new

    ex = assert_raises TypeError do
      class << klass
        mattr_accessor :my_attr
      end
    end
    assert_equal "module attributes should be defined directly on class, not singleton", ex.message

    assert_not_includes Module.class_variables, :@@my_attr
  end
end
