require 'cases/helper'
require 'models/user'

class SecureTokenTest < ActiveRecord::TestCase
  setup do
    @user = User.new
  end

  test "assing unique token values" do
    @user.save
    assert_not_nil @user.token
    assert_not_nil @user.auth_token
  end

  test "regenerate the secure key for the attribute" do
    @user.save
    old_token = @user.token
    old_auth_token = @user.auth_token
    @user.regenerate_token
    @user.regenerate_auth_token

    assert_not_equal @user.token, old_token
    assert_not_equal @user.auth_token, old_auth_token
  end

  test "raise and exception when with 10 attemps is reached" do
    User.stubs(:exists?).returns(*Array.new(10, true))
    assert_raises(RuntimeError) do
      @user.save
    end
  end

  test "assing unique token after 9 attemps reached" do
    User.stubs(:exists?).returns(*Array.new(10){ |i| i == 9 ? false : true})
    @user.save
    assert_not_nil @user.token
    assert_not_nil @user.auth_token
  end
end
