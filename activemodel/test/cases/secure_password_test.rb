require 'cases/helper'
require 'models/user'
require 'models/visitor'

class SecurePasswordTest < ActiveModel::TestCase
  setup do
    ActiveModel::SecurePassword.min_cost = true

    @user = User.new
    @visitor = Visitor.new

    # Simulate loading an existing user from the DB
    @existing_user = User.new
    @existing_user.password_digest = BCrypt::Password.create('password', cost: BCrypt::Engine::MIN_COST)
  end

  teardown do
    ActiveModel::SecurePassword.min_cost = false
  end

  test "create and updating without validations" do
    assert @visitor.valid?(:create), 'visitor should be valid'
    assert @visitor.valid?(:update), 'visitor should be valid'

    @visitor.password = '123'
    @visitor.password_confirmation = '456'

    assert @visitor.valid?(:create), 'visitor should be valid'
    assert @visitor.valid?(:update), 'visitor should be valid'
  end

  test "create a new user with validation and a blank password" do
    @user.password = ''
    assert !@user.valid?(:create), 'user should be invalid'
    assert_equal 1, @user.errors.count
    assert_equal ["can't be blank"], @user.errors[:password]
  end

  test "create a new user with validation and a nil password" do
    @user.password = nil
    assert !@user.valid?(:create), 'user should be invalid'
    assert_equal 1, @user.errors.count
    assert_equal ["can't be blank"], @user.errors[:password]
  end

  test "create a new user with validation and a blank password confirmation" do
    @user.password = 'password'
    @user.password_confirmation = ''
    assert !@user.valid?(:create), 'user should be invalid'
    assert_equal 1, @user.errors.count
    assert_equal ["doesn't match Password"], @user.errors[:password_confirmation]
  end

  test "create a new user with validation and a nil password confirmation" do
    @user.password = 'password'
    @user.password_confirmation = nil
    assert @user.valid?(:create), 'user should be valid'
  end

  test "create a new user with validation and an incorrect password confirmation" do
    @user.password = 'password'
    @user.password_confirmation = 'something else'
    assert !@user.valid?(:create), 'user should be invalid'
    assert_equal 1, @user.errors.count
    assert_equal ["doesn't match Password"], @user.errors[:password_confirmation]
  end

  test "create a new user with validation and a correct password confirmation" do
    @user.password = 'password'
    @user.password_confirmation = 'something else'
    assert !@user.valid?(:create), 'user should be invalid'
    assert_equal 1, @user.errors.count
    assert_equal ["doesn't match Password"], @user.errors[:password_confirmation]
  end

  test "update an existing user with validation and no change in password" do
    assert @existing_user.valid?(:update), 'user should be valid'
  end

  test "updating an existing user with validation and a blank password" do
    @existing_user.password = ''
    assert @existing_user.valid?(:update), 'user should be valid'
  end

  test "updating an existing user with validation and a blank password and password_confirmation" do
    @existing_user.password = ''
    @existing_user.password_confirmation = ''
    assert @existing_user.valid?(:update), 'user should be valid'
  end

  test "updating an existing user with validation and a nil password" do
    @existing_user.password = nil
    assert !@existing_user.valid?(:update), 'user should be invalid'
    assert_equal 1, @existing_user.errors.count
    assert_equal ["can't be blank"], @existing_user.errors[:password]
  end

  test "updating an existing user with validation and a blank password confirmation" do
    @existing_user.password = 'password'
    @existing_user.password_confirmation = ''
    assert !@existing_user.valid?(:update), 'user should be invalid'
    assert_equal 1, @existing_user.errors.count
    assert_equal ["doesn't match Password"], @existing_user.errors[:password_confirmation]
  end

  test "updating an existing user with validation and a nil password confirmation" do
    @existing_user.password = 'password'
    @existing_user.password_confirmation = nil
    assert @existing_user.valid?(:update), 'user should be valid'
  end

  test "updating an existing user with validation and an incorrect password confirmation" do
    @existing_user.password = 'password'
    @existing_user.password_confirmation = 'something else'
    assert !@existing_user.valid?(:update), 'user should be invalid'
    assert_equal 1, @existing_user.errors.count
    assert_equal ["doesn't match Password"], @existing_user.errors[:password_confirmation]
  end

  test "updating an existing user with validation and a correct password confirmation" do
    @existing_user.password = 'password'
    @existing_user.password_confirmation = 'something else'
    assert !@existing_user.valid?(:update), 'user should be invalid'
    assert_equal 1, @existing_user.errors.count
    assert_equal ["doesn't match Password"], @existing_user.errors[:password_confirmation]
  end

  test "updating an existing user with validation and a blank password digest" do
    @existing_user.password_digest = ''
    assert !@existing_user.valid?(:update), 'user should be invalid'
    assert_equal 1, @existing_user.errors.count
    assert_equal ["can't be blank"], @existing_user.errors[:password]
  end

  test "updating an existing user with validation and a nil password digest" do
    @existing_user.password_digest = nil
    assert !@existing_user.valid?(:update), 'user should be invalid'
    assert_equal 1, @existing_user.errors.count
    assert_equal ["can't be blank"], @existing_user.errors[:password]
  end

  test "setting a blank password should not change an existing password" do
    @existing_user.password = ''
    assert @existing_user.password_digest == 'password'
  end

  test "setting a nil password should clear an existing password" do
    @existing_user.password = nil
    assert_equal nil, @existing_user.password_digest
  end  

  test "authenticate" do
    @user.password = "secret"

    assert !@user.authenticate("wrong")
    assert @user.authenticate("secret")
  end

  test "Password digest cost defaults to bcrypt default cost when min_cost is false" do
    ActiveModel::SecurePassword.min_cost = false

    @user.password = "secret"
    assert_equal BCrypt::Engine::DEFAULT_COST, @user.password_digest.cost
  end

  test "Password digest cost honors bcrypt cost attribute when min_cost is false" do
    ActiveModel::SecurePassword.min_cost = false
    BCrypt::Engine.cost = 5

    @user.password = "secret"
    assert_equal BCrypt::Engine.cost, @user.password_digest.cost
  end

  test "Password digest cost can be set to bcrypt min cost to speed up tests" do
    ActiveModel::SecurePassword.min_cost = true

    @user.password = "secret"
    assert_equal BCrypt::Engine::MIN_COST, @user.password_digest.cost
  end
end
