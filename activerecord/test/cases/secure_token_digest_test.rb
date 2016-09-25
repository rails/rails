require "cases/helper"
require "models/user"

class SecureTokenDigestTest < ActiveRecord::TestCase
  setup do
    @user = User.new
  end

  def test_token_values_are_not_automatically_generated_on_create
    @user.save

    assert_nil @user.activation_token
    assert_nil @user.activation_token_digest
  end

  def test_regenerating_the_secure_digest
    @user.regenerate_activation_token

    assert_not_nil @user.activation_token
    assert_not_nil @user.activation_token_digest
  end

  def test_token_value_not_overwritten_when_present
    @user.activation_token = "custom-secure-token"
    @user.save

    assert_equal @user.activation_token, "custom-secure-token"
  end

  def test_token_and_digest_replaced_on_regeneration
    @user.activation_token = "custom-secure-token"
    @user.save

    old_token = @user.activation_token
    old_digest = @user.activation_token_digest
    @user.regenerate_activation_token

    assert_not_equal @user.activation_token, old_token
    assert_not_equal @user.activation_token_digest, old_digest
  end

  def test_authenticated_returns_correct_result
    @user.regenerate_activation_token
    correct_token = @user.activation_token

    assert @user.authenticated?(:activation_token, correct_token)
    assert_not @user.authenticated?(:activation_token, 'notright')
  end
end
