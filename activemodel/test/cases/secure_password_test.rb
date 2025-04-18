# frozen_string_literal: true

require "cases/helper"
require "models/user"
require "models/pilot"
require "models/visitor"

class SecurePasswordTest < ActiveModel::TestCase
  setup do
    # Used only to speed up tests
    @original_min_cost = ActiveModel::SecurePassword.min_cost
    ActiveModel::SecurePassword.min_cost = true

    @user = User.new
    @visitor = Visitor.new
    @pilot = Pilot.new

    # Simulate loading an existing user from the DB
    @existing_user = User.new
    @existing_user.password_digest = BCrypt::Password.create("password", cost: BCrypt::Engine::MIN_COST)
    @existing_user.changes_applied
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

  test "create a new user with validation and password length greater than 72 characters" do
    @user.password = "a" * 73
    @user.password_confirmation = "a" * 73
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["is too long"], @user.errors[:password]
  end

  test "create a new user with validation and password byte size greater than 72 bytes" do
    # Create a password with 73 bytes by using a 3-byte Unicode character (e.g., "あ") 24 times, followed by a 1-byte character "a".
    # This will result in a password length of 25 characters, but with a byte size of 73.
    @user.password = "あ" * 24 + "a"
    @user.password_confirmation = "あ" * 24 + "a"
    assert_not @user.valid?(:create), "user should be invalid"
    assert_equal 1, @user.errors.count
    assert_equal ["is too long"], @user.errors[:password]
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

  test "resetting password to nil clears the password cache" do
    @user.password = "password"
    @user.password = nil
    assert_nil @user.password
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
    assert_equal ["is too long"], @existing_user.errors[:password]
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

  test "updating an existing user with validation and a correct password challenge" do
    @existing_user.password = "new password"
    @existing_user.password_challenge = "password"
    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and a nil password challenge" do
    @existing_user.password = "new password"
    @existing_user.password_challenge = nil
    assert @existing_user.valid?(:update), "user should be valid"
  end

  test "updating an existing user with validation and a blank password challenge" do
    @existing_user.password = "new password"
    @existing_user.password_challenge = ""
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["is invalid"], @existing_user.errors[:password_challenge]
  end

  test "updating an existing user with validation and an incorrect password challenge" do
    @existing_user.password = "new password"
    @existing_user.password_challenge = "new password"
    assert_not @existing_user.valid?(:update), "user should be invalid"
    assert_equal 1, @existing_user.errors.count
    assert_equal ["is invalid"], @existing_user.errors[:password_challenge]
  end

  test "updating a user without dirty tracking and a correct password challenge" do
    validatable_visitor = Class.new(Visitor) do
      attr_accessor :untracked_digest
      has_secure_password :untracked
    end.new

    validatable_visitor.untracked = "password"
    assert validatable_visitor.valid?(:update), "user should be valid"

    validatable_visitor.untracked_challenge = "password"
    assert_not validatable_visitor.valid?(:update), "user should be invalid"
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

  test "override secure password attribute" do
    assert_nil @user.password_called

    @user.password = "secret"

    assert_equal "secret", @user.password
    assert_equal 1, @user.password_called

    @user.password = "terces"

    assert_equal "terces", @user.password
    assert_equal 2, @user.password_called
  end

  test "authenticate" do
    @user.password = "secret"
    @user.recovery_password = "42password"

    assert_equal false, @user.authenticate("wrong")
    assert_equal @user, @user.authenticate("secret")

    assert_equal false, @user.authenticate_password("wrong")
    assert_equal @user, @user.authenticate_password("secret")

    assert_equal false, @user.authenticate_recovery_password("wrong")
    assert_equal @user, @user.authenticate_recovery_password("42password")
  end

  test "authenticate should return false and not raise when password digest is blank" do
    @user.password_digest = " "
    assert_equal false, @user.authenticate(" ")
  end

  test "password_salt" do
    @user.password = "secret"
    assert_equal @user.password_digest.salt, @user.password_salt
  end

  test "password_salt should return nil when password is nil" do
    @user.password = nil
    assert_nil @user.password_salt
  end

  test "password_salt should return nil when password digest is nil" do
    @user.password_digest = nil
    assert_nil @user.password_salt
  end

  test "Password digest cost defaults to bcrypt default cost when min_cost is false" do
    ActiveModel::SecurePassword.min_cost = false

    @user.password = "secret"
    assert_equal BCrypt::Engine::DEFAULT_COST, @user.password_digest.cost
  end

  test "Password digest cost honors bcrypt cost attribute when min_cost is false" do
    original_bcrypt_cost = BCrypt::Engine.cost
    ActiveModel::SecurePassword.min_cost = false
    BCrypt::Engine.cost = 5

    @user.password = "secret"
    assert_equal BCrypt::Engine.cost, @user.password_digest.cost
  ensure
    BCrypt::Engine.cost = original_bcrypt_cost
  end

  test "Password digest cost can be set to bcrypt min cost to speed up tests" do
    ActiveModel::SecurePassword.min_cost = true

    @user.password = "secret"
    assert_equal BCrypt::Engine::MIN_COST, @user.password_digest.cost
  end

  test "password reset token" do
    assert_not @person.respond_to? :password_reset_token
    assert_equal "password_reset-token-900", @pilot.password_reset_token

    assert_equal "finding-for-password_reset-by-999", Pilot.find_by_password_reset_token("999")
    assert_equal "finding-for-password_reset-by-999!", Pilot.find_by_password_reset_token!("999")
  end
end
