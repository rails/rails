require 'abstract_unit'
require 'active_support/deprecation'
require 'active_support/basic_object'


class BasicObjectTest < ActiveSupport::TestCase
  test 'BasicObject warns about deprecation when inherited from' do
    warn = 'ActiveSupport::BasicObject is deprecated! Use ActiveSupport::ProxyObject instead.'
    ActiveSupport::Deprecation.expects(:warn).with(warn).once
    Class.new(ActiveSupport::BasicObject)
  end
end