require 'cases/helper'
require 'models/user'
require 'minitest/mock'

class SecurePasswordTest < ActiveRecord::TestCase
  setup { @user = User.new(name: "kuldeep Aggarwal") }

  test "create a new user with unique secure_key" do
    assert_nil @user.secure_key
    @user.save
    assert_not_nil @user.secure_key
    assert !User.where(secure_key: @user.secure_key).where.not(id: @user.id).exists?
  end

  test "default length of secure key is set to 24" do
    @user.save
    assert_equal 24, @user.secure_key.length
  end

  test "create user with customised length of secure key" do
    User.has_secure_key :another_secure_key, key_length: 30
    @user.save
    assert_equal 30, @user.another_secure_key.length
    User._create_callbacks.each { |callback| User._create_callbacks.delete(callback) if callback.kind == :before && callback.filter == :set_generated_another_secure_key_key }
  end

  test "regenerate the secure key for the attribute" do
    old_key = @user.secure_key
    @user.rekey_secure_key!
    assert_not_equal @user.secure_key, old_key
  end

  test "raise ActiveRecord::RetriesLimitReached if unable to find a unique value after 1000 tries" do
    @user.save
    another_user = User.new(name: "KD Aggarwal")
    SecureRandom.stubs(:hex).returns(@user.secure_key)
    assert_raises(ActiveRecord::RetriesLimitReached) do
      another_user.save
    end
  end
end
