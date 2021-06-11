# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::KeyProviderCallsTest < ActiveRecord::EncryptionTestCase
  fixtures :encrypted_books, :posts

  test "calls #encryption_key only once when creating a record" do
    assert_equal 0, key_provider.encryption_key_calls

    ActiveRecord::Encryption.configure(
      key_provider: key_provider.new,
      primary_key: "secret",
      key_derivation_salt: "salt",
      deterministic_key: nil
    )

    create_book

    assert_equal 2, key_provider.encryption_key_calls
  end

  private
    def key_provider
      MyKeyProvider
    end

    def create_book
      Book.create!(name: "CapSens to the moon")
    end

    class MyKeyProvider
      def encryption_key
        @@encryption_key_calls = 0 unless defined?(@@encryption_key_calls)
        @@encryption_key_calls += 1

        ActiveRecord::Encryption::Key.new("0" * 32)
      end

      def decryption_keys(encrypted_message)
        [ActiveRecord::Encryption::Key.new("0" * 32)]
      end

      class << self
        def encryption_key_calls
          @@encryption_key_calls = 0 unless defined?(@@encryption_key_calls)
          @@encryption_key_calls
        end
      end
    end

    class Book < ActiveRecord::Base
      encrypts :name
    end
end
