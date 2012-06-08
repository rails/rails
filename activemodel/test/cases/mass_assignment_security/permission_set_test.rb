require "cases/helper"

class PermissionSetTest < ActiveModel::TestCase

  def setup
    @permission_list = ActiveModel::MassAssignmentSecurity::PermissionSet.new
  end

  test "+ stringifies added collection values" do
    symbol_collection = [ :admin ]
    new_list = @permission_list += symbol_collection

    assert new_list.include?('admin'), "did not add collection to #{@permission_list.inspect}}"
  end

  test "+ compacts added collection values" do
    added_collection = [ nil ]
    new_list = @permission_list + added_collection
    assert_equal new_list, @permission_list, "did not add collection to #{@permission_list.inspect}}"
  end

  test "include? normalizes multi-parameter keys" do
    multi_param_key = 'admin(1)'
    new_list = @permission_list += [ 'admin' ]

    assert new_list.include?(multi_param_key), "#{multi_param_key} not found in #{@permission_list.inspect}"
  end

  test "include? normal keys" do
    normal_key = 'admin'
    new_list = @permission_list +=  [ normal_key ]

    assert new_list.include?(normal_key), "#{normal_key} not found in #{@permission_list.inspect}"
  end

end
