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
      env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true, rails_env: "test"
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

  test "rails_env configuration lookups" do
    @credentials.write({ foo: "global foo", test: { foo: "test foo" } }.to_yaml)

    assert_equal "global foo", @credentials.foo
    assert_equal "test foo", @credentials.env.foo
    assert_equal "test foo", @credentials.env[:foo]
    assert_equal "test foo", @credentials.env.dig(:foo)
    assert_equal "test foo", @credentials.env.fetch(:foo)
    assert_equal ({ foo: "test foo" }), @credentials.env.config

    assert_nil @credentials.env.missing
    assert_raises ::KeyError do @credentials.env.missing! end
    assert_nil @credentials.env[:missing]
    assert_nil @credentials.env.dig(:missing)
    assert_equal "missing key", @credentials.env.fetch(:missing, "missing key")

    # Check that credentials and credentials.env get the new configuration.
    @credentials.write({ foo: "global bar", test: { foo: "test bar" } }.to_yaml)
    assert_equal "global bar", @credentials.foo
    assert_equal "global bar", @credentials[:foo]
    assert_equal "test bar", @credentials.env.foo
  end
end
