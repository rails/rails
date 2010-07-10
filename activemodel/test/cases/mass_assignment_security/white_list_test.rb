require "cases/helper"

class WhiteListTest < ActiveModel::TestCase

  def setup
    @white_list   = ActiveModel::MassAssignmentSecurity::WhiteList.new
    @included_key = 'first_name'
    @white_list  += [ @included_key ]
  end

  test "deny? is false for included items" do
    assert_equal false, @white_list.deny?(@included_key)
  end

  test "deny? is true for non-included items" do
    assert_equal true, @white_list.deny?('admin')
  end

  test "sanitize attributes" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied', 'admin(1)' => 'denied' }
    attributes = @white_list.sanitize(original_attributes)

    assert attributes.key?('first_name'), "Allowed key shouldn't be rejected"
    assert !attributes.key?('admin'),     "Denied key should be rejected"
    assert !attributes.key?('admin(1)'),  "Multi-parameter key should be detected"
  end

end
