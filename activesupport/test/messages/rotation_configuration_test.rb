# frozen_string_literal: true

require_relative '../abstract_unit'
require 'active_support/messages/rotation_configuration'

class MessagesRotationConfiguration < ActiveSupport::TestCase
  def setup
    @config = ActiveSupport::Messages::RotationConfiguration.new
  end

  def test_signed_configurations
    @config.rotate :signed, 'older secret', salt: 'salt', digest: 'SHA1'
    @config.rotate :signed, 'old secret', salt: 'salt', digest: 'SHA256'

    assert_equal [
      [ 'older secret', salt: 'salt', digest: 'SHA1' ],
      [ 'old secret', salt: 'salt', digest: 'SHA256' ] ], @config.signed
  end

  def test_encrypted_configurations
    @config.rotate :encrypted, 'old raw key', cipher: 'aes-256-gcm'

    assert_equal [ [ 'old raw key', cipher: 'aes-256-gcm' ] ], @config.encrypted
  end
end
