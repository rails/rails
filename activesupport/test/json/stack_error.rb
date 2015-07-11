require 'abstract_unit'
class JSONStackLevelTooDeepWithoutActiveSupportTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def test_stack_error_without_active_support_JSON
    require 'json'
    obj = Struct.new(:key).new
    assert_equal "\"#<struct key=nil>\"", JSON.dump(obj)
  end
end

class JSONStackLevelTooDeepWithActiveSupportTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def test_stack_error_with_active_support_JSON
    require 'active_support/json'
    obj = Struct.new(:key).new
    assert_equal "\"#<struct key=nil>\"", JSON.dump(obj)
  end
end

