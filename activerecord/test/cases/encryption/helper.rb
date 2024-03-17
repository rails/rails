# frozen_string_literal: true

require "cases/helper"

class ActiveRecord::Fixture
  prepend ActiveRecord::Encryption::EncryptedFixtures
end

module ActiveRecord::Encryption
  module EncryptionHelpers
    def assert_ciphertext_decrypts_to(model, attribute_name, ciphertext)
      assert_not_equal model.public_send(attribute_name), ciphertext
      assert_not_equal model.read_attribute(attribute_name), ciphertext
      cleartext = model.type_for_attribute(attribute_name).deserialize(ciphertext)
      assert_equal model.read_attribute(attribute_name), cleartext
    end

    def assert_encrypted_attribute(model, attribute_name, expected_value)
      assert_ciphertext_decrypts_to model, attribute_name, model.read_attribute_before_type_cast(attribute_name)
      assert_equal expected_value, model.public_send(attribute_name)
      unless model.new_record?
        model.reload
        assert_ciphertext_decrypts_to model, attribute_name, model.read_attribute_before_type_cast(attribute_name)
        assert_equal expected_value, model.public_send(attribute_name)
      end
    end

    def assert_invalid_key_cant_read_attribute(model, attribute_name)
      if model.type_for_attribute(attribute_name).key_provider.respond_to?(:keys=)
        assert_invalid_key_cant_read_attribute_with_custom_key_provider(model, attribute_name)
      else
        assert_invalid_key_cant_read_attribute_with_default_key_provider(model, attribute_name)
      end
    end

    def assert_not_encrypted_attribute(model, attribute_name, expected_value)
      assert_equal expected_value, model.send(attribute_name)
      assert_equal expected_value, model.read_attribute_before_type_cast(attribute_name)
    end

    def assert_encrypted_record(model)
      encrypted_attributes = model.class.encrypted_attributes.find_all { |attribute_name| model.send(attribute_name).present? }
      assert_not encrypted_attributes.empty?, "The model has no encrypted attributes with content to check (they are all blank)"

      encrypted_attributes.each do |attribute_name|
        assert_encrypted_attribute model, attribute_name, model.send(attribute_name)
      end
    end

    def assert_encryptor_works_with(key_provider)
      encryptor = ActiveRecord::Encryption::Encryptor.new

      encrypted_message = encryptor.encrypt("some text", key_provider: key_provider)
      assert_equal "some text", encryptor.decrypt(encrypted_message, key_provider: key_provider)
    end

    private
      def build_keys(count = 3)
        count.times.collect do |index|
          password = "some secret #{index}"
          secret = ActiveRecord::Encryption.key_generator.derive_key_from(password)
          ActiveRecord::Encryption::Key.new(secret)
        end
      end

      def with_key_provider(key_provider, &block)
        ActiveRecord::Encryption.with_encryption_context key_provider: key_provider, &block
      end

      def with_envelope_encryption(&block)
        @envelope_encryption_key_provider ||= ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
        with_key_provider @envelope_encryption_key_provider, &block
      end

      def create_unencrypted_book_ignoring_case(name:)
        book = ActiveRecord::Encryption.without_encryption do
          EncryptedBookThatIgnoresCase.create!(name: name)
        end

        # Skip type casting to simulate an upcase value. Not supported in AR without using private apis
        EncryptedBookThatIgnoresCase.lease_connection.execute <<~SQL
          UPDATE encrypted_books SET name = '#{name}' WHERE id = #{book.id};
        SQL

        book.reload
      end

      def assert_invalid_key_cant_read_attribute_with_default_key_provider(model, attribute_name)
        model.reload

        ActiveRecord::Encryption.with_encryption_context key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("a different 256 bits key for now") do
          assert_raises ActiveRecord::Encryption::Errors::Decryption do
            model.public_send(attribute_name)
          end
        end
      end

      def assert_invalid_key_cant_read_attribute_with_custom_key_provider(model, attribute_name)
        attribute_type = model.type_for_attribute(attribute_name)

        model.reload

        original_keys = attribute_type.key_provider.keys
        attribute_type.key_provider.keys = [ ActiveRecord::Encryption::Key.derive_from("other custom attribute secret") ]

        assert_raises ActiveRecord::Encryption::Errors::Decryption do
          model.public_send(attribute_name)
        end
      ensure
        attribute_type.key_provider.keys = original_keys
      end
  end
end

# We eager load encrypted attribute types as they are declared, so that they pick up the
# default encryption setup for tests. Because we load those lazily when used, this prevents
# side effects where some tests modify encryption config settings affecting others.
#
# Notice that we clear the declaration listeners when each test start, so this will only affect
# the classes loaded before tests starts, not those declared during tests.
ActiveRecord::Encryption.on_encrypted_attribute_declared do |klass, attribute_name|
  klass.type_for_attribute(attribute_name)
end

class ActiveRecord::EncryptionTestCase < ActiveRecord::TestCase
  include ActiveRecord::Encryption::EncryptionHelpers

  ENCRYPTION_PROPERTIES_TO_RESET = {
    config: %i[ primary_key deterministic_key key_derivation_salt store_key_references hash_digest_class
      key_derivation_salt support_unencrypted_data encrypt_fixtures
      forced_encoding_for_deterministic_encryption ],
    context: %i[ key_provider ]
  }

  setup do
    ENCRYPTION_PROPERTIES_TO_RESET.each do |key, properties|
      properties.each do |property|
        instance_variable_set "@_original_encryption_#{key}_#{property}", ActiveRecord::Encryption.public_send(key).public_send(property)
      end
    end
    ActiveRecord::Encryption.config.previous_schemes.clear
    ActiveRecord::Encryption.encrypted_attribute_declaration_listeners&.clear
  end

  teardown do
    ENCRYPTION_PROPERTIES_TO_RESET.each do |key, properties|
      properties.each do |property|
        ActiveRecord::Encryption.public_send(key).public_send("#{property}=", instance_variable_get("@_original_encryption_#{key}_#{property}"))
      end
    end
  end
end
