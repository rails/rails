require 'cases/helper'

class ModelWithAttributes
  include ActiveModel::AttributeMethods
  
  attribute_method_suffix ''
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
end
