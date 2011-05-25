require 'cases/helper'
require 'models/user'
require 'models/visitor'
require 'models/administrator'

class AlternateUser
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  module PhonyAuthenticator

    def self.crypt(plaintext)
      "ciphertext"
    end 

    def self.authenticate(ciphertext, plaintext)
      true
    end 

  end 
  
  has_secure :secret, :column => "crypted_secret", :authenticator => PhonyAuthenticator

  attr_accessor :crypted_secret
end 

class SecurePasswordTest < ActiveModel::TestCase

  setup do
    @user = User.new
  end

  test "blank password" do
    user = User.new
    user.password = ''
    assert !user.valid?, 'user should be invalid'
  end

  test "nil password" do
    user = User.new
    user.password = nil
    assert !user.valid?, 'user should be invalid'
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

  test "defaults can be overwritten" do
    user = AlternateUser.new
    user.secret = "password"
    
    assert_equal "password", user.secret
    assert user.authenticate("password")
  end 

end
