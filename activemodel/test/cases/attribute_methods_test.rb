require 'cases/helper'

class ModelWithAttributes
  include ActiveModel::AttributeMethods

  attribute_method_suffix ''

  def attributes
    { :foo => 'value of foo' }
  end

private
  def attribute(name)
    attributes[name.to_sym]
  end
end

class ModelWithAttributes2
  include ActiveModel::AttributeMethods

  attribute_method_suffix '_test'
end

class AttributeMethodsTest < ActiveModel::TestCase
  test 'unrelated classes should not share attribute method matchers' do
    assert_not_equal ModelWithAttributes.send(:attribute_method_matchers),
                     ModelWithAttributes2.send(:attribute_method_matchers)
  end

  test '#define_attribute_methods generates attribute methods' do
    ModelWithAttributes.define_attribute_methods([:foo])

    assert ModelWithAttributes.attribute_methods_generated?
    assert_respond_to ModelWithAttributes.new, :foo
    assert_equal "value of foo", ModelWithAttributes.new.foo
  end

  test '#undefine_attribute_methods removes attribute methods' do
    ModelWithAttributes.define_attribute_methods([:foo])
    ModelWithAttributes.undefine_attribute_methods

    assert !ModelWithAttributes.attribute_methods_generated?
    assert !ModelWithAttributes.new.respond_to?(:foo)
    assert_raises(NoMethodError) { ModelWithAttributes.new.foo }
  end
end
