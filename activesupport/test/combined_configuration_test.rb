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

    @credentials.write({ available_in_both: "cred", only_in_credentials: "cred", false: false, nested: { available_in_both: "cred", only_in_credentials: "cred" } }.to_yaml)

    ENV["ONLY_IN_ENV"] = "env"
    ENV["AVAILABLE_IN_BOTH"] = "env"
    ENV["NESTED__ONLY_IN_ENV"] = "env"
    ENV["NESTED__AVAILABLE_IN_BOTH"] = "env"

    @envs = ActiveSupport::EnvConfiguration.new
    @combined = ActiveSupport::CombinedConfiguration.new(@envs, @credentials)
  end

  teardown do
    FileUtils.rm_rf @tmpdir
    ENV.delete("ONLY_IN_ENV")
    ENV.delete("AVAILABLE_IN_BOTH")
    ENV.delete("NESTED__ONLY_IN_ENV")
    ENV.delete("NESTED__AVAILABLE_IN_BOTH")
  end

  test "require key present in env not credentials" do
    assert_equal "env", @combined.require(:only_in_env)
  end

  test "require key present in credentials not env" do
    assert_equal "cred", @combined.require(:only_in_credentials)
  end

  test "require key present in env and credentials" do
    assert_equal "env", @combined.require(:available_in_both)
  end

  test "read nested key present in env not credentials" do
    assert_equal "env", @combined.require(:nested, :only_in_env)
  end

  test "read nested key present in credentials not env" do
    assert_equal "cred", @combined.require(:nested, :only_in_credentials)
  end

  test "read nested key present in env and credentials" do
    assert_equal "env", @combined.require(:nested, :available_in_both)
  end

  test "require key with a false value" do
    assert_equal false, @combined.require(:false)
  end

  test "option key with a false value" do
    assert_equal false, @combined.option(:false)
  end

  test "require with missing key raises key error" do
    assert_raise(KeyError, match: "Missing key: [:gone]") do
      @combined.require(:gone)
    end
  end

  test "require with missing nested key raises key error" do
    assert_raise(KeyError, match: "Missing key: [:gone, :missing]") do
      @combined.require(:gone, :missing)
    end
  end
end
