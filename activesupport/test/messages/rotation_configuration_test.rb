# frozen_string_literal: true

require "abstract_unit"
require "active_support/messages/rotation_configuration"

class MessagesRotationConfiguration < ActiveSupport::TestCase
  def setup
    @config = ActiveSupport::Messages::RotationConfiguration.new
  end

  def test_signed_configurations
    @config.rotate :signed, secret: "older secret", salt: "salt", digest: "SHA1"
    @config.rotate :signed, secret: "old secret", salt: "salt", digest: "SHA256"

    assert_equal [{
      secret: "older secret", salt: "salt", digest: "SHA1"
    }, {
      secret: "old secret", salt: "salt", digest: "SHA256"
    }], @config.signed
  end

  def test_encrypted_configurations
    @config.rotate :encrypted, raw_key: "old raw key", cipher: "aes-256-gcm"

    assert_equal [{
      raw_key: "old raw key", cipher: "aes-256-gcm"
    }], @config.encrypted
  end

  def test_rotate_without_kind
    @config.rotate secret: "older secret", salt: "salt", digest: "SHA1"
    @config.rotate raw_key: "old raw key", cipher: "aes-256-gcm"

    expected = [{
      secret: "older secret", salt: "salt", digest: "SHA1"
    }, {
      raw_key: "old raw key", cipher: "aes-256-gcm"
    }]

    assert_equal expected, @config.encrypted
    assert_equal expected, @config.signed
  end
end
