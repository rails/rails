require "cases/helper"

class BlackListTest < ActiveModel::TestCase

  def setup
    @black_list   = ActiveModel::MassAssignmentSecurity::BlackList.new
    @included_key = 'admin'
    @black_list  += [ @included_key ]
  end

  test "deny? is true for included items" do
    assert_equal true, @black_list.deny?(@included_key)
  end

  test "deny? is false for non-included items" do
    assert_equal false, @black_list.deny?('first_name')
  end

  test "sanitize attributes" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied', 'admin(1)' => 'denied' }
    attributes = @black_list.sanitize(original_attributes)

    assert attributes.key?('first_name'), "Allowed key shouldn't be rejected"
    assert !attributes.key?('admin'),     "Denied key should be rejected"
    assert !attributes.key?('admin(1)'),  "Multi-parameter key should be detected"
  end

end
