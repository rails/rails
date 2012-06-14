require 'cases/helper'
require 'models/user'
require 'models/visitor'
require 'models/auth_user'
require 'models/administrator'

class SecurePasswordTest < ActiveModel::TestCase

  setup do
    @user = User.new
    @visitor = Visitor.new
    @auth_user = AuthUser.new
  end

  test "blank password" do
    @user.password = @visitor.password = @auth_user.pw = ''
    assert !@user.valid?(:create), 'user should be invalid'
    assert @visitor.valid?(:create), 'visitor should be valid'
    assert !@auth_user.valid?(:create), 'auth user should be valid'
  end

  test "nil password" do
    @user.password = @visitor.password = @auth_user.pw = nil
    assert !@user.valid?(:create), 'user should be invalid'
    assert @visitor.valid?(:create), 'visitor should be valid'
    assert !@auth_user.valid?(:create), 'auth user should be valid'
  end

  test "blank password doesn't override previous password" do
    @user.password = 'test'
    @user.password = ''
    assert_equal @user.password, 'test'
  end

  test "password must be present" do
    assert !@user.valid?(:create)
    assert !@auth_user.valid?(:create)
    assert_equal 1, @user.errors.size
    assert_equal 1, @auth_user.errors.size
    assert_equal [:password], @user.errors.keys
    assert_equal [:pw], @auth_user.errors.keys
  end

  test "match confirmation" do
    @user.password = @visitor.password = @auth_user.pw = "thiswillberight"
    @user.password_confirmation = @visitor.password_confirmation = @auth_user.pw_confirmation = "wrong"

    assert !@user.valid?
    assert @visitor.valid?
    assert !@auth_user.valid?

    assert_equal [:password_confirmation], @user.errors.keys
    assert_equal [:pw_confirmation], @auth_user.errors.keys

    @user.password_confirmation = @auth_user.pw_confirmation = "thiswillberight"
    assert @user.valid?
    assert @auth_user.valid?
  end

  test "authenticate" do
    @user.password = @auth_user.pw = "secret"

    assert !@user.authenticate("wrong")
    assert @user.authenticate("secret")
    assert !@auth_user.authenticate("wrong")
    assert @auth_user.authenticate("secret")
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

  test "humanizes the column name for error" do
    begin
      @auth_user.run_callbacks :create
    rescue RuntimeError => e
      assert_equal "Encrypted password missing on new record", e.message
    end
  end

  test "recogizes the column name passed in as an attribute" do
    assert @auth_user.methods.include?(:encrypted_password)
  end

  test "recognizes the attribute name passed in as an attribute" do
    assert @auth_user.methods.include?(:pw)
  end

  test "adds column name passed in to attributes_protected_by_default" do
    assert @auth_user.class.attributes_protected_by_default.include?("encrypted_password")
  end
end
