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

end
