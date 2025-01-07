# frozen_string_literal: true

require "cases/helper"

class ComplexPasswordTest < ActiveModel::TestCase
  class ComplexPasswordUser
    include ActiveModel::Model
    include ActiveModel::ComplexPassword

    attr_accessor :password

    has_complex_password
  end

  test "password must contain a number" do
    user = ComplexPasswordUser.new(password: "Abcdef!")
    user.valid?
    assert_equal ["must contain at least one number"], user.errors[:password]
  end

  test "password must contain a special character" do
    user = ComplexPasswordUser.new(password: "Abcdef1")
    user.valid?
    assert_equal ["must contain at least one special character"], user.errors[:password]
  end

  test "password must contain at least one lowercase letter" do
    user = ComplexPasswordUser.new(password: "ABCDEF1!")
    user.valid?
    assert_equal ["must contain at least one lowercase letter"], user.errors[:password]
  end

  test "password must contain an uppercase letter" do
    user = ComplexPasswordUser.new(password: "abcdef1!")
    user.valid?
    assert_equal ["must contain at least one uppercase letter"], user.errors[:password]
  end

  test "password must not be blank" do
    user = ComplexPasswordUser.new(password: "")
    user.valid?
    assert_equal ["can't be blank"], user.errors[:password]
  end

  test "password is valid" do
    user = ComplexPasswordUser.new(password: "Abc123!")
    user.valid?
    assert_empty user.errors[:password]
  end
end
