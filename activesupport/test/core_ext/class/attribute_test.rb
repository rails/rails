require 'abstract_unit'
require 'active_support/core_ext/class/attribute'

class ClassAttributeTest < ActiveSupport::TestCase
  class Base
    class_attribute :setting
  end

  class Subclass < Base
  end

  def setup
    @klass = Class.new { class_attribute :setting }
    @sub = Class.new(@klass)
  end

  test 'defaults to nil' do
    assert_nil @klass.setting
    assert_nil @sub.setting
  end

  test 'inheritable' do
    @klass.setting = 1
    assert_equal 1, @sub.setting
  end

  test 'overridable' do
    @sub.setting = 1
    assert_nil @klass.setting

    @klass.setting = 2
    assert_equal 1, @sub.setting

    assert_equal 1, Class.new(@sub).setting
  end

  test 'query method' do
    assert_equal false, @klass.setting?
    @klass.setting = 1
    assert_equal true, @klass.setting?
  end

  test 'no instance delegates' do
    assert_raise(NoMethodError) { @klass.new.setting }
    assert_raise(NoMethodError) { @klass.new.setting? }
  end
end
