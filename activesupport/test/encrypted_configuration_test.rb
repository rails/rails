# frozen_string_literal: true

require "abstract_unit"
require "active_support/encrypted_configuration"

class EncryptedConfigurationTest < ActiveSupport::TestCase
  setup do
    @credentials_config_path = File.join(Dir.tmpdir, "credentials.yml.enc")

    @credentials_key_path = File.join(Dir.tmpdir, "master.key")
    File.write(@credentials_key_path, ActiveSupport::EncryptedConfiguration.generate_key)

    @credentials = ActiveSupport::EncryptedConfiguration.new(
      config_path: @credentials_config_path, key_path: @credentials_key_path,
      env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true
    )
  end

  teardown do
    FileUtils.rm_rf @credentials_config_path
    FileUtils.rm_rf @credentials_key_path
  end

  test "reading configuration by env key" do
    FileUtils.rm_rf @credentials_key_path

    begin
      ENV["RAILS_MASTER_KEY"] = ActiveSupport::EncryptedConfiguration.generate_key
      @credentials.write({ something: { good: true, bad: false } }.to_yaml)

      assert @credentials[:something][:good]
      assert_not @credentials.dig(:something, :bad)
      assert_nil @credentials.fetch(:nothing, nil)
    ensure
      ENV["RAILS_MASTER_KEY"] = nil
    end
  end

  test "reading configuration by key file" do
    @credentials.write({ something: { good: true } }.to_yaml)

    assert @credentials.something[:good]
  end

  test "reading comment-only configuration" do
    ActiveSupport::EncryptedFile.new(
      content_path: @credentials_config_path, key_path: @credentials_key_path,
      env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true
    ).write("# comment")

    assert_equal @credentials.config, {}
  end

  test "change configuration by key file" do
    @credentials.write({ something: { good: true } }.to_yaml)
    @credentials.change do |config_file|
      config = YAML.load(config_file.read)
      config_file.write config.merge(new: "things").to_yaml
    end

    assert @credentials.something[:good]
    assert_equal "things", @credentials[:new]
  end

  test "raise error when writing an invalid format value" do
    assert_raise(Psych::SyntaxError) do
      @credentials.change do |config_file|
        config_file.write "login: *login\n  username: dummy"
      end
    end
  end

  test "raises key error when accessing config via bang method" do
    assert_raise(KeyError) { @credentials.something! }
  end
end
