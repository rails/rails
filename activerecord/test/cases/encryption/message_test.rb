# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::MessageTest < ActiveSupport::TestCase
  test "add_header lets you add headers" do
    message = ActiveRecord::Encryption::Message.new
    message.headers[:header_1] = "value 1"

    assert_equal "value 1", message.headers[:header_1]
  end

  test "add_headers lets you add multiple headers" do
    message = ActiveRecord::Encryption::Message.new
    message.headers.add(header_1: "value 1", header_2: "value 2")
    assert_equal "value 1", message.headers[:header_1]
    assert_equal "value 2", message.headers[:header_2]
  end

  test "headers can't be overridden" do
    message = ActiveRecord::Encryption::Message.new
    message.headers.add(header_1: "value 1")

    assert_raises(ActiveRecord::Encryption::Errors::EncryptedContentIntegrity) do
      message.headers.add(header_1: "value 1")
    end

    assert_raises(ActiveRecord::Encryption::Errors::EncryptedContentIntegrity) do
      message.headers.add(header_1: "value 1")
    end
  end

  test "validates that payloads are either nil or strings" do
    assert_raises ActiveRecord::Encryption::Errors::ForbiddenClass do
      ActiveRecord::Encryption::Message.new(payload: Date.new)
      ActiveRecord::Encryption::Message.new(payload: [])
    end

    ActiveRecord::Encryption::Message.new
    ActiveRecord::Encryption::Message.new(payload: "")
    ActiveRecord::Encryption::Message.new(payload: "Some payload")
  end
end
