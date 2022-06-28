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

  test "attachment_service is nil" do
    default_reflection = EncryptedMessage.reflect_on_association(:rich_text_content).class_name.safe_constantize.reflect_on_attachment(:embeds)
    assert_nil default_reflection.options[:service_name]
  end

  test "raises error when misconfigured service is passed" do
    error = assert_raises ArgumentError do
      EncryptedMessage.class_eval do
        has_rich_text :content, encrypted: true, attachment_service: :unknown
      end
    end

    assert_match(/Cannot configure service :unknown for ActionText::EncryptedRichText#embeds/, error.message)
  end

  test "attachment_service is set to the one provided" do
    EncryptedMessage.class_eval do
      has_rich_text :content, encrypted: true, attachment_service: :local
    end
    reflection = EncryptedMessage.reflect_on_association(:rich_text_content).class_name.safe_constantize.reflect_on_attachment(:embeds)
    assert_equal :local, reflection.options[:service_name]
  ensure
    EncryptedMessage.class_eval do
      has_rich_text :content, encrypted: true
    end
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
