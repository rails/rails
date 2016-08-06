require "abstract_unit"
require "active_support/core_ext/class/attribute"

class ClassAttributeTest < ActiveSupport::TestCase
  def setup
    @klass = Class.new { class_attribute :setting }
    @sub = Class.new(@klass)
  end

  test "defaults to nil" do
    assert_nil @klass.setting
    assert_nil @sub.setting
  end

  test "inheritable" do
    @klass.setting = 1
    assert_equal 1, @sub.setting
  end

  test "overridable" do
    @sub.setting = 1
    assert_nil @klass.setting

    @klass.setting = 2
    assert_equal 1, @sub.setting

    assert_equal 1, Class.new(@sub).setting
  end

  test "predicate method" do
    assert_equal false, @klass.setting?
    @klass.setting = 1
    assert_equal true, @klass.setting?
  end

  test "instance reader delegates to class" do
    assert_nil @klass.new.setting

    @klass.setting = 1
    assert_equal 1, @klass.new.setting
  end

  test "instance override" do
    object = @klass.new
    object.setting = 1
    assert_nil @klass.setting
    @klass.setting = 2
    assert_equal 1, object.setting
  end

  test "instance predicate" do
    object = @klass.new
    assert_equal false, object.setting?
    object.setting = 1
    assert_equal true, object.setting?
  end

  test "disabling instance writer" do
    object = Class.new { class_attribute :setting, :instance_writer => false }.new
    assert_raise(NoMethodError) { object.setting = "boom" }
  end

  test "disabling instance reader" do
    object = Class.new { class_attribute :setting, :instance_reader => false }.new
    assert_raise(NoMethodError) { object.setting }
    assert_raise(NoMethodError) { object.setting? }
  end

  test "disabling both instance writer and reader" do
    object = Class.new { class_attribute :setting, :instance_accessor => false }.new
    assert_raise(NoMethodError) { object.setting }
    assert_raise(NoMethodError) { object.setting? }
    assert_raise(NoMethodError) { object.setting = "boom" }
  end

  test "disabling instance predicate" do
    object = Class.new { class_attribute :setting, instance_predicate: false }.new
    assert_raise(NoMethodError) { object.setting? }
  end

  test "works well with singleton classes" do
    object = @klass.new
    object.singleton_class.setting = "foo"
    assert_equal "foo", object.setting
  end

  test "setter returns set value" do
    val = @klass.send(:setting=, 1)
    assert_equal 1, val
  end
end
