require "cases/helper"

class PermissionSetTest < ActiveRecord::TestCase

  def setup
    @permission_list = ActiveRecord::MassAssignmentSecurity::PermissionSet.new
  end

  test "+ stringifies added collection values" do
    symbol_collection = [ :admin ]
    @permission_list += symbol_collection

    assert @permission_list.include?('admin'), "did not add collection to #{@permission_list.inspect}}"
  end

  test "include? normalizes multi-parameter keys" do
    multi_param_key = 'admin(1)'
    @permission_list += [ 'admin' ]

    assert_equal true, @permission_list.include?(multi_param_key), "#{multi_param_key} not found in #{@permission_list.inspect}"
  end

  test "include? normal keys" do
    normal_key = 'admin'
    @permission_list +=  [ normal_key ]

    assert_equal true,  @permission_list.include?(normal_key), "#{normal_key} not found in #{@permission_list.inspect}"
  end

end
