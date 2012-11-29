require 'cases/helper'
require 'models/user'
require 'models/oauthed_user'
require 'models/visitor'
require 'models/administrator'

class SecurePasswordTest < ActiveModel::TestCase
  setup do
    ActiveModel::SecurePassword.cost = 4

    @user = User.new
    @visitor = Visitor.new
    @oauthed_user = OauthedUser.new
  end

  teardown do
    ActiveModel::SecurePassword.cost = 10
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

  test "User should not be created with blank digest" do
    assert_raise RuntimeError do
      @user.run_callbacks :create
    end
    @user.password = "supersecretpassword"
    assert_nothing_raised do
      @user.run_callbacks :create
    end
  end

  test "Oauthed user can be created with blank digest" do
    assert_nothing_raised do
      @oauthed_user.run_callbacks :create
    end
  end

  test "Password digest cost will be set to BCrypt's MIN_COST if the cost was set below MIN_COST in the User's model" do
    ActiveModel::SecurePassword.cost = 1

    @user.password = "secret"
    assert_equal BCrypt::Engine::MIN_COST, @user.password_digest.cost
  end

  test "Password digest cost will be set to bcrypt default cost when cost is not set by User" do
    ActiveModel::SecurePassword.cost = 10

    @user.password = "secret"
    assert_equal 10, @user.password_digest.cost
  end

  test "User should be able to set the Password digest cost" do
    ActiveModel::SecurePassword.cost = 11

    @user.password = "secret"
    assert_equal 11, @user.password_digest.cost
  end
end
