require 'cases/helper'
require 'models/user'

class SecureTokenTest < ActiveRecord::TestCase
  setup do
    @user = User.new
  end

  def test_token_values_are_generated_for_specified_attributes_and_persisted_on_save
    @user.save
    assert_not_nil @user.token
    assert_not_nil @user.auth_token
    assert_not_nil @user.auth_secret
  end

  def test_regenerating_the_secure_token
    @user.save
    old_token = @user.token
    old_auth_token = @user.auth_token
    old_auth_secret = @user.auth_secret
    @user.regenerate_token
    @user.regenerate_auth_token
    @user.regenerate_auth_secret

    assert_not_equal @user.token, old_token
    assert_not_equal @user.auth_token, old_auth_token
    assert_not_equal @user.auth_secret, old_auth_secret
  end

  def test_token_value_not_overwritten_when_present
    @user.token = "custom-secure-token"
    @user.save

    assert_equal @user.token, "custom-secure-token"
  end

  def test_default_token_size
    @user.save

    assert_equal @user.token.length, 24
    assert_equal @user.auth_token.length, 24
  end

  def test_token_size_should_be_customizable
    @user.save

    assert_equal @user.auth_secret.length, 80
  end
end
