require 'cases/helper'
require 'models/user'
require 'models/visitor'
require 'models/administrator'
require 'models/customer'

class SecurePasswordTest < ActiveModel::TestCase

  setup do
    @user = User.new
  end

  test "blank password" do
    @user.password = ''
    assert !@user.valid?, 'user should be invalid'
  end

  test "nil password" do
    @user.password = nil
    assert !@user.valid?, 'user should be invalid'
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
    assert Visitor.active_authorizers[:default].kind_of?(ActiveModel::MassAssignmentSecurity::BlackList)
    assert Visitor.active_authorizers[:default].include?(:password_digest)
  end

  test "Administrator's mass_assignment_authorizer should be WhiteList" do
    active_authorizer = Administrator.active_authorizers[:default]
    assert active_authorizer.kind_of?(ActiveModel::MassAssignmentSecurity::WhiteList)
    assert !active_authorizer.include?(:password_digest)
    assert active_authorizer.include?(:name)
  end

  test "Customer#password should not be blank" do
    @customer = Customer.new
    @customer.password = ''
    assert !@customer.valid?, 'customer should be invalid'
  end

  test "Customer#password can be nil" do
    @customer = Customer.new
    @customer.password = nil
    assert @customer.valid?
  end

  test "can't be authenticated if password_digest is nil" do
    @customer = Customer.new
    assert !@customer.authenticate("")
    assert !@customer.authenticate(nil)
  end
end
