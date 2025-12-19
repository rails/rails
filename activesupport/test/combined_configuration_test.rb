# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/combined_configuration"
require "active_support/encrypted_configuration"
require "active_support/env_configuration"

class EncryptedConfigurationTest < ActiveSupport::TestCase
  setup do
    @tmpdir = Dir.mktmpdir("config-")
    @credentials_config_path = File.join(@tmpdir, "credentials.yml.enc")

    @credentials_key_path = File.join(@tmpdir, "master.key")
    File.write(@credentials_key_path, ActiveSupport::EncryptedConfiguration.generate_key)

    @credentials = ActiveSupport::EncryptedConfiguration.new(
      config_path: @credentials_config_path, key_path: @credentials_key_path,
      env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true
    )

    @credentials.write({ available_in_both: "cred", only_in_credentials: "cred", nested: { available_in_both: "cred", only_in_credentials: "cred" } }.to_yaml)


    @envs = ActiveSupport::EnvConfiguration.new
    ENV["ONLY_IN_ENV"] = "env"
    ENV["AVAILABLE_IN_BOTH"] = "env"
    ENV["NESTED__ONLY_IN_ENV"] = "env"
    ENV["NESTED__AVAILABLE_IN_BOTH"] = "env"

    @combined = ActiveSupport::CombinedConfiguration.new(@envs, @credentials)
  end

  teardown do
    FileUtils.rm_rf @tmpdir
    ENV.delete("ONLY_IN_ENV")
    ENV.delete("AVAILABLE_IN_BOTH")
    ENV.delete("NESTED__ONLY_IN_ENV")
    ENV.delete("NESTED__AVAILABLE_IN_BOTH")
  end

  test "read key present in env not credentials" do
    assert_equal "env", @combined[:only_in_env]
  end

  test "read key present in credentials not env" do
    assert_equal "cred", @combined[:only_in_credentials]
  end

  test "read key present in env and credentials" do
    assert_equal "env", @combined[:available_in_both]
  end

  test "read nested key present in env not credentials" do
    assert_equal "env", @combined.dig(:nested, :only_in_env)
  end

  test "read nested key present in credentials not env" do
    assert_equal "cred", @combined.dig(:nested, :only_in_credentials)
  end

  test "read nested key present in env and credentials" do
    assert_equal "env", @combined.dig(:nested, :available_in_both)
  end

  test "read using combined key method" do
    assert_equal "env", @combined.grab(:only_in_env)
    assert_equal "env", @combined.grab(:nested, :only_in_env)
  end
end
