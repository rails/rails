# frozen_string_literal: true

require "test_helper"

class ActionText::ModelEncryptionTest < ActiveSupport::TestCase
  test "encrypt content based on :encrypted option at declaration time" do
    encrypted_message = EncryptedMessage.create!(subject: "Greetings", content: "Hey there")
    assert_encrypted_rich_text_attribute encrypted_message, :content, "Hey there"

    clear_message = Message.create!(subject: "Greetings", content: "Hey there")
    assert_not_encrypted_rich_text_attribute clear_message, :content, "Hey there"
  end

  test "include rich text attributes when encrypting the model" do
    content = "<p>the space force is here, we are safe now!</p>"

    message = ActiveRecord::Encryption.without_encryption do
      EncryptedMessage.create!(subject: "Greetings", content: content)
    end

    message.encrypt

    assert_encrypted_rich_text_attribute(message, :content, content)
  end

  test "encrypts lets you skip rich texts when encrypting" do
    content = "<p>the space force is here, we are safe now!</p>"

    message = ActiveRecord::Encryption.without_encryption do
      EncryptedMessage.create!(subject: "Greetings", content: content)
    end

    message.encrypt(skip_rich_texts: true)

    assert_not_encrypted_rich_text_attribute(message, :content, content)
  end

  private
    def assert_encrypted_rich_text_attribute(model, attribute_name, expected_value)
      assert_not_equal expected_value, model.send(attribute_name).ciphertext_for(:body)
      assert_equal expected_value, model.reload.send(attribute_name).body.to_html
    end

    def assert_not_encrypted_rich_text_attribute(model, attribute_name, expected_value)
      assert_equal expected_value, model.send(attribute_name).ciphertext_for(:body)
      assert_equal expected_value, model.reload.send(attribute_name).body.to_html
    end
end

