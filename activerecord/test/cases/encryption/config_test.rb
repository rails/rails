# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::ConfigTest < ActiveRecord::EncryptionTestCase
  setup do
    @config = ActiveRecord::Encryption::Config.new
  end

  test "credential(key) will raise a config error when key is not set" do
    @config.primary_key = nil
    assert_raises ActiveRecord::Encryption::Errors::Configuration do
      @config.credential(:primary_key)
    end

    @config.primary_key = "some key"
    assert_nothing_raised do
      @config.credential(:primary_key)
    end
  end
end
