require 'cases/helper'
require 'models/user'
require 'models/visitor'
require 'models/administrator'

class SecurePasswordTest < ActiveModel::TestCase

  setup do
    @user = User.new
  end

  test "password must be present" do
    assert !@user.valid?
    assert_equal 1, @user.errors.size
  end

  test "password must match confirmation" do
    @user.password = "thiswillberight"
    @user.password_confirmation = "wrong"

    assert !@user.valid?

    @user.password_confirmation = "thiswillberight"

    assert @user.valid?
  end

  test "authenticate" do
    @user.password = "secret"

    assert !@user.authenticate("wrong")
    assert @user.authenticate("secret")
  end

  test "visitor#password_digest should be protected against mass assignment" do
    assert Visitor.active_authorizer.kind_of?(ActiveModel::MassAssignmentSecurity::BlackList)
    assert Visitor.active_authorizer.include?(:password_digest)
  end

  test "Administrator's mass_assignment_authorizer should be WhiteList" do
    assert Administrator.active_authorizer.kind_of?(ActiveModel::MassAssignmentSecurity::WhiteList)
    assert !Administrator.active_authorizer.include?(:password_digest)
    assert Administrator.active_authorizer.include?(:name)
  end
end
