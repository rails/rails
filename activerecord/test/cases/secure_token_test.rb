# frozen_string_literal: true

require "cases/helper"
require "models/user"

class SecureTokenTest < ActiveRecord::TestCase
  setup do
    @user = User.new
  end

  def test_token_values_are_generated_for_specified_attributes_and_persisted_on_save
    @user.save
    assert_not_nil @user.token
    assert_not_nil @user.auth_token
  end

  def test_regenerating_the_secure_token
    @user.save
    old_token = @user.token
    old_auth_token = @user.auth_token
    @user.regenerate_token
    @user.regenerate_auth_token

    assert_not_equal @user.token, old_token
    assert_not_equal @user.auth_token, old_auth_token
  end

  def test_token_value_not_overwritten_when_present
    @user.token = "custom-secure-token"
    @user.save

    assert_equal "custom-secure-token", @user.token
  end
end
