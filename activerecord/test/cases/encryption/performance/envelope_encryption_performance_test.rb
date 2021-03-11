# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

class ActiveRecord::Encryption::EvenlopeEncryptionPerformanceTest < ActiveRecord::TestCase
  fixtures :encrypted_books

  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    @envelope_encryption_key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
  end

  test "performance when saving records" do
    baseline = -> { create_book_without_encryption }

    assert_slower_by_at_most 1.4, baseline: baseline do
      with_envelope_encryption do
        create_book
      end
    end
  end

  test "reading an encrypted attribute multiple times is as fast as reading a regular attribute" do
    with_envelope_encryption do
      baseline = -> { encrypted_books(:awdr).created_at }
      book = create_book
      assert_slower_by_at_most 1.05, baseline: baseline, duration: 3 do
        book.name
      end
    end
  end

  private
    def create_book_without_encryption
      ActiveRecord::Encryption.without_encryption { create_book }
    end

    def create_book
      EncryptedBook.create! name: "Dune"
    end

    def encrypt_unencrypted_book
      book = create_book_without_encryption
      with_envelope_encryption do
        book.encrypt
      end
    end

    def with_envelope_encryption(&block)
      with_key_provider @envelope_encryption_key_provider, &block
    end
end
