require 'cases/helper'
require 'models/user'

class OneTimePasswordTest < ActiveModel::TestCase
  setup do
    @user = User.new
    @user.email = 'guille@rubyonrails.org'
    @user.password = ':grin:'
    @user.run_callbacks :create
  end

  test "authenticate with otp" do
    code = @user.otp_code

    assert @user.authenticate_otp(code)
  end

  test "authenticate with otp when drift is allowed" do
    code = @user.otp_code(Time.now - 30)

    assert @user.authenticate_otp(code, drift: 60)
  end

  test "otp code" do
    assert_match(/\d{6}/, @user.otp_code.to_s)
  end

  test "provisioning_uri with provided account" do
    assert_match %r{otpauth://totp/guille\?secret=\w{16}}, @user.provisioning_uri("guille")
  end

  test "provisioning_uri with email field" do
    assert_match %r{otpauth://totp/guille@rubyonrails\.org\?secret=\w{16}}, @user.provisioning_uri
  end
end
