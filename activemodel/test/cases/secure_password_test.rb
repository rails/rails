# frozen_string_literal: true

require "cases/helper"
require "models/user"
require "models/visitor"

class SecurePasswordTest < ActiveModel::TestCase
  setup do
    # Used only to speed up tests
    @original_min_cost = ActiveModel::SecurePassword.min_cost
    ActiveModel::SecurePassword.min_cost = true

    @user = User.new
    @visitor = Visitor.new

    # Simulate loading an existing user from the DB
    @existing_user = User.new
    @existing_user.password_digest = BCrypt::Password.create("password", cost: BCrypt::Engine::MIN_COST)
  end

  teardown do
    ActiveModel::SecurePassword.min_cost = @original_min_cost
  end

  test "automatically include ActiveModel::Validations when validations are enabled" do
    assert_respond_to @user, :valid?
  end

  test "don't include ActiveModel::Validations when validations are disabled" do
    assert_not_respond_to @visitor, :valid?
  end

  test "create a new user with validations and valid password/confirmation" do
    @user.password = "password"
    @user.password_confirmation = "password"

    assert @user.valid?(:create), "user should be valid"

    @user.password = "a" * 72
    @user.password_confirmation = "a" * 72

    assert @user.valid?(:create), "user should be valid"
  end

  test "create a new user with validation and a spaces only password" do
    @user.password = " " * 72
    assert @user.valid?(:create), "user should be valid"
  end

  test "create a new user with validation and a blank password" do
    @user.password = ""
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["can't be blank"], @user.errors[:password]
  end

  test "create a new user with validation and a nil password" do
    @user.password = nil
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["can't be blank"], @user.errors[:password]
  end

  test "create a new user with validation and password length greater than 72" do
    @user.password = "a" * 73
    @user.password_confirmation = "a" * 73
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["is too long (maximum is 72 characters)"], @user.errors[:password]
  end

  test "create a new user with validation and a blank password confirmation" do
    @user.password = "password"
    @user.password_confirmation = ""
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["doesn't match Password"], @user.errors[:password_confirmation]
  end

  test "create a new user with validation and a nil password confirmation" do
    @user.password = "password"
    @user.password_confirmation = nil
    assert @user.valid?(:create), "user should be valid"
  end

  test "create a new user with validation and an incorrect password confirmation" do
    @user.password = "password"
    @user.password_confirmation = "something else"
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["doesn't match Password"], @user.errors[:password_confirmation]
  end

  test "update an existing user with validation and no change in password" do
    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "update an existing user with validations and valid password/confirmation" do
    @existing_user.password = "password"
    @existing_user.password_confirmation = "password"

    assert @existing_user.valid?(:update), "user should be valid"

    @existing_user.password = "a" * 72
    @existing_user.password_confirmation = "a" * 72

    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and a blank password" do
    @existing_user.password = ""
    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and a spaces only password" do
    @user.password = " " * 72
    assert @user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and a blank password and password_confirmation" do
    @existing_user.password = ""
    @existing_user.password_confirmation = ""
    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and a nil password" do
    @existing_user.password = nil
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["can't be blank"], @existing_user.errors[:password]
  end

  test "updating an existing user with validation and password length greater than 72" do
    @existing_user.password = "a" * 73
    @existing_user.password_confirmation = "a" * 73
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["is too long (maximum is 72 characters)"], @existing_user.errors[:password]
  end

  test "updating an existing user with validation and a blank password confirmation" do
    @existing_user.password = "password"
    @existing_user.password_confirmation = ""
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["doesn't match Password"], @existing_user.errors[:password_confirmation]
  end

  test "updating an existing user with validation and a nil password confirmation" do
    @existing_user.password = "password"
    @existing_user.password_confirmation = nil
    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and an incorrect password confirmation" do
    @existing_user.password = "password"
    @existing_user.password_confirmation = "something else"
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["doesn't match Password"], @existing_user.errors[:password_confirmation]
  end

  test "updating an existing user with validation and a blank password digest" do
    @existing_user.password_digest = ""
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["can't be blank"], @existing_user.errors[:password]
  end

  test "updating an existing user with validation and a nil password digest" do
    @existing_user.password_digest = nil
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["can't be blank"], @existing_user.errors[:password]
  end

  test "setting a blank password should not change an existing password" do
    @existing_user.password = ""
    assert @existing_user.password_digest == "password"
  end

  test "setting a nil password should clear an existing password" do
    @existing_user.password = nil
    assert_nil @existing_user.password_digest
  end

  test "authenticate" do
    @user.password = "secret"
    @user.activation_token = "new_token"

    assert_not @user.authenticate("wrong")
    assert @user.authenticate("secret")

    assert !@user.authenticate_activation_token("wrong")
    assert @user.authenticate_activation_token("new_token")
  end

  test "Password digest cost defaults to bcrypt default cost when min_cost is false" do
    ActiveModel::SecurePassword.min_cost = false

    @user.password = "secret"
    assert_equal BCrypt::Engine::DEFAULT_COST, @user.password_digest.cost
  end

  test "Password digest cost honors bcrypt cost attribute when min_cost is false" do
    begin
      original_bcrypt_cost = BCrypt::Engine.cost
      ActiveModel::SecurePassword.min_cost = false
      BCrypt::Engine.cost = 5

      @user.password = "secret"
      assert_equal BCrypt::Engine.cost, @user.password_digest.cost
    ensure
      BCrypt::Engine.cost = original_bcrypt_cost
    end
  end

  test "Password digest cost can be set to bcrypt min cost to speed up tests" do
    ActiveModel::SecurePassword.min_cost = true

    @user.password = "secret"
    assert_equal BCrypt::Engine::MIN_COST, @user.password_digest.cost
  end
end
