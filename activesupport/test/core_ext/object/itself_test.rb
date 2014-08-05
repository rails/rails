require 'abstract_unit'
require 'active_support/core_ext/object'

class Object::ItselfTest < ActiveSupport::TestCase
  test 'itself returns self' do
    object = 'fun'
    assert_equal object, object.itself
  end
end
