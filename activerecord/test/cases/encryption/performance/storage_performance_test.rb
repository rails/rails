# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::StoragePerformanceTest < ActiveRecord::EncryptionTestCase
  test "storage overload without storing keys is acceptable" do
    assert_storage_performance size: 2, overload_less_than: 47
    assert_storage_performance size: 50, overload_less_than: 4
    assert_storage_performance size: 255, overload_less_than: 1.6
    assert_storage_performance size: 1.kilobyte, overload_less_than: 1.15

    [500.kilobytes, 1.megabyte, 10.megabyte].each do |size|
      assert_storage_performance size: size, overload_less_than: 1.03
    end
  end

  test "storage overload storing keys is acceptable for DerivedSecretKeyProvider" do
    ActiveRecord::Encryption.config.store_key_references = true

    ActiveRecord::Encryption.with_encryption_context key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("some secret") do
      assert_storage_performance size: 2, overload_less_than: 54
      assert_storage_performance size: 50, overload_less_than: 3.5
      assert_storage_performance size: 255, overload_less_than: 1.64
      assert_storage_performance size: 1.kilobyte, overload_less_than: 1.18

      [500.kilobytes, 1.megabyte, 10.megabyte].each do |size|
        assert_storage_performance size: size, overload_less_than: 1.03
      end
    end
  end

  test "storage overload storing keys is acceptable for EnvelopeEncryptionKeyProvider" do
    ActiveRecord::Encryption.config.store_key_references = true

    with_envelope_encryption do
      assert_storage_performance size: 2, overload_less_than: 126
      assert_storage_performance size: 50, overload_less_than: 6.28
      assert_storage_performance size: 255, overload_less_than: 2.2
      assert_storage_performance size: 1.kilobyte, overload_less_than: 1.3

      [500.kilobytes, 1.megabyte, 10.megabyte].each do |size|
        assert_storage_performance size: size, overload_less_than: 1.015
      end
    end
  end

  private
    def assert_storage_performance(size:, overload_less_than:)
      clear_content = SecureRandom.urlsafe_base64(size).first(size) # .alphanumeric is very slow for large sizes
      encrypted_content = encryptor.encrypt(clear_content)

      puts "#{clear_content.bytesize}; #{encrypted_content.bytesize}; #{(encrypted_content.bytesize / clear_content.bytesize.to_f)}"

      overload_factor = encrypted_content.bytesize.to_f / clear_content.bytesize
      assert\
        overload_factor <= overload_less_than,
        "Expecting an storage overload of #{overload_less_than} at most for #{size} bytes, but got #{overload_factor} instead"
    end

    def encryptor
      @encryptor ||= ActiveRecord::Encryption::Encryptor.new
    end

    def cipher
      @cipher ||= ActiveRecord::Encryption::Cipher.new
    end
end
