# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::EncryptionPropertiesTest < ActiveSupport::TestCase
  setup do
    @properties = ActiveRecord::Encryption::Properties.new
  end

  test "behaves like a hash" do
    @properties[:key_1] = "value 1"
    @properties[:key_2] = "value 2"

    assert_equal "value 1", @properties[:key_1]
    assert_equal "value 2", @properties[:key_2]
  end

  test "defines custom accessors for some default properties" do
    auth_tag = "some auth tag"

    @properties.auth_tag = auth_tag
    assert_equal auth_tag, @properties.auth_tag
    assert_equal auth_tag, @properties[:at]
  end

  test "raises EncryptedContentIntegrity when trying to override properties" do
    @properties[:key_1] = "value 1"

    assert_raises ActiveRecord::Encryption::Errors::EncryptedContentIntegrity do
      @properties[:key_1] = "value 1"
    end
  end

  test "add will add all the properties passed" do
    @properties.add(key_1: "value 1", key_2: "value 2")

    assert_equal "value 1", @properties[:key_1]
    assert_equal "value 2", @properties[:key_2]
  end

  test "validate allowed types on creation" do
    example_of_valid_values.each do |value|
      ActiveRecord::Encryption::Properties.new(some_value: value)
    end

    assert_raises ActiveRecord::Encryption::Errors::ForbiddenClass do
      ActiveRecord::Encryption::Properties.new(my_class: MyClass.new)
    end
  end

  test "validate allowed_types setting headers" do
    example_of_valid_values.each.with_index do |value, index|
      @properties["some_value_#{index}"] = value
    end

    assert_raises ActiveRecord::Encryption::Errors::ForbiddenClass do
      @properties["some_value"] = MyClass.new
    end
  end

  MyClass = Struct.new(:some_value)

  def example_of_valid_values
    ["a string", 123, 123.5, true, false, nil, :a_symbol, ActiveRecord::Encryption::Message.new]
  end
end
