# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/combined_configuration"
require "active_support/encrypted_configuration"
require "active_support/env_configuration"
require "active_support/dot_env_configuration"

class CombinedConfigurationTest < ActiveSupport::TestCase
  setup do
    @tmpdir = Dir.mktmpdir("config-")
    @credentials_config_path = File.join(@tmpdir, "credentials.yml.enc")
    @env_file_path = File.join(@tmpdir, ".env")

    @credentials_key_path = File.join(@tmpdir, "master.key")
    File.write(@credentials_key_path, ActiveSupport::EncryptedConfiguration.generate_key)

    @credentials = ActiveSupport::EncryptedConfiguration.new(
      config_path: @credentials_config_path, key_path: @credentials_key_path,
      env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true
    )

    @credentials.write({
      available_in_all: "cred",
      available_in_dotenv_and_cred: "cred",
      only_in_credentials: "cred",
      false: false,
      nested: {
        available_in_all: "cred",
        available_in_dotenv_and_cred: "cred",
        only_in_credentials: "cred"
      }
    }.to_yaml)

    # .env file values (middle priority)
    File.write(@env_file_path, <<~DOTENV)
      AVAILABLE_IN_ALL=dotenv
      AVAILABLE_IN_ENV_AND_DOTENV=dotenv
      AVAILABLE_IN_DOTENV_AND_CRED=dotenv
      ONLY_IN_DOTENV=dotenv
      NESTED__AVAILABLE_IN_ALL=dotenv
      NESTED__AVAILABLE_IN_ENV_AND_DOTENV=dotenv
      NESTED__AVAILABLE_IN_DOTENV_AND_CRED=dotenv
      NESTED__ONLY_IN_DOTENV=dotenv
    DOTENV

    # ENV values (highest priority)
    ENV["ONLY_IN_ENV"] = "env"
    ENV["AVAILABLE_IN_ALL"] = "env"
    ENV["AVAILABLE_IN_ENV_AND_DOTENV"] = "env"
    ENV["NESTED__ONLY_IN_ENV"] = "env"
    ENV["NESTED__AVAILABLE_IN_ALL"] = "env"
    ENV["NESTED__AVAILABLE_IN_ENV_AND_DOTENV"] = "env"

    @envs = ActiveSupport::EnvConfiguration.new
    @dotenvs = ActiveSupport::DotEnvConfiguration.new(@env_file_path)
    @combined = ActiveSupport::CombinedConfiguration.new(@envs, @dotenvs, @credentials)
  end

  teardown do
    FileUtils.rm_rf @tmpdir
    ENV.delete("ONLY_IN_ENV")
    ENV.delete("AVAILABLE_IN_ALL")
    ENV.delete("AVAILABLE_IN_ENV_AND_DOTENV")
    ENV.delete("NESTED__ONLY_IN_ENV")
    ENV.delete("NESTED__AVAILABLE_IN_ALL")
    ENV.delete("NESTED__AVAILABLE_IN_ENV_AND_DOTENV")
  end

  test "require key present only in env" do
    assert_equal "env", @combined.require(:only_in_env)
  end

  test "require key present only in dotenv" do
    assert_equal "dotenv", @combined.require(:only_in_dotenv)
  end

  test "require key present only in credentials" do
    assert_equal "cred", @combined.require(:only_in_credentials)
  end

  test "require key present in all three sources returns env" do
    assert_equal "env", @combined.require(:available_in_all)
  end

  test "require key present in env and dotenv returns env" do
    assert_equal "env", @combined.require(:available_in_env_and_dotenv)
  end

  test "require key present in dotenv and credentials returns dotenv" do
    assert_equal "dotenv", @combined.require(:available_in_dotenv_and_cred)
  end

  test "read nested key present only in env" do
    assert_equal "env", @combined.require(:nested, :only_in_env)
  end

  test "read nested key present only in dotenv" do
    assert_equal "dotenv", @combined.require(:nested, :only_in_dotenv)
  end

  test "read nested key present only in credentials" do
    assert_equal "cred", @combined.require(:nested, :only_in_credentials)
  end

  test "read nested key present in all three sources returns env" do
    assert_equal "env", @combined.require(:nested, :available_in_all)
  end

  test "read nested key present in env and dotenv returns env" do
    assert_equal "env", @combined.require(:nested, :available_in_env_and_dotenv)
  end

  test "read nested key present in dotenv and credentials returns dotenv" do
    assert_equal "dotenv", @combined.require(:nested, :available_in_dotenv_and_cred)
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

  test "inspect does not show configuration values but shows keys as symbols" do
    secret_env_value = "secret_env_value"
    ENV["SECRET_ENV"] = secret_env_value
    @envs.reload

    assert_no_match(/#{secret_env_value}/, @combined.inspect)
    assert_match(/keys=/, @combined.inspect)
    assert_match(/:secret_env/, @combined.inspect)
    assert_match(/\A#<ActiveSupport::CombinedConfiguration:0x[0-9a-f]+ keys=\[.*\]>\z/, @combined.inspect)
  ensure
    ENV.delete("SECRET_ENV")
  end
end
