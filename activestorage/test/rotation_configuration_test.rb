# frozen_string_literal: true

require "test_helper"
require "active_storage/rotation_configuration"

class RotationConfiguration < ActiveSupport::TestCase
  def setup
    @config = ActiveStorage::RotationConfiguration.new
  end

  def test_rotation_configurations
    @config.rotate "older secret", salt: "salt", digest: "SHA1"
    @config.rotate "old secret", salt: "salt", digest: "SHA256"

    assert_equal [
      [ "older secret", salt: "salt", digest: "SHA1" ],
      [ "old secret", salt: "salt", digest: "SHA256" ] ], @config.rotations
  end
end
