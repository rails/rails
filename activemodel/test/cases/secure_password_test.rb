require 'cases/helper'
require 'models/user'
require 'models/visitor'
require 'models/administrator'

class SecurePasswordTest < ActiveModel::TestCase

  setup do
    @user = User.new
    @visitor = Visitor.new
  end

  test "blank password" do
    @user.password = @visitor.password = ''
    assert !@user.valid?(:create), 'user should be invalid'
    assert @visitor.valid?(:create), 'visitor should be valid'
  end

  test "nil password" do
    @user.password = @visitor.password = nil
    assert !@user.valid?(:create), 'user should be invalid'
    assert @visitor.valid?(:create), 'visitor should be valid'
  end

  test "blank password doesn't override previous password" do
    @user.password = 'test'
    @user.password = ''
    assert_equal @user.password, 'test'
  end

  test "password must be present" do
    assert !@user.valid?(:create)
    assert_equal 1, @user.errors.size
  end

  test "match confirmation" do
    @user.password = @visitor.password = "thiswillberight"
    @user.password_confirmation = @visitor.password_confirmation = "wrong"

    assert !@user.valid?
    assert @visitor.valid?

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
  
  test "User should not be created with blank digest" do
    assert_raise RuntimeError do 
      @user.run_callbacks :create
    end
    @user.password = "supersecretpassword"
    assert_nothing_raised do
      @user.run_callbacks :create
    end
  end
end
