require 'abstract_unit'
require 'active_support/core_ext/object'

class Object::SelfTest < ActiveSupport::TestCase
  test 'self returns self' do
    object = 'fun'
    assert_equal object, object.self
  end
end
