# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/encrypted_configuration"

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
  end

  teardown do
    FileUtils.rm_rf @tmpdir
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
    @credentials.write({ something: { good: true, bad: false, nested: { foo: "bar" } } }.to_yaml)

    assert @credentials.something[:good]
    assert_not @credentials.something[:bad]
    assert @credentials.something.good
    assert_not @credentials.something.bad
    assert_equal "bar", @credentials.dig(:something, :nested, :foo)
    assert_equal "bar", @credentials.something.nested.foo
    assert_equal [:something], @credentials.keys
    assert_equal [:good, :bad, :nested], @credentials.something.keys
    assert_equal ({ good: true, bad: false, nested: { foo: "bar" } }), @credentials.something
  end

  test "reading comment-only configuration" do
    @credentials.write("# comment")

    assert_equal({}, @credentials.config)
  end

  test "writing with element assignment and reading with element reference" do
    @credentials[:foo] = 42
    assert_equal 42, @credentials[:foo]
  end

  test "writing with dynamic accessor and reading with element reference" do
    @credentials.foo = 42
    assert_equal 42, @credentials[:foo]
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

  test "raises helpful error when loading invalid content" do
    @credentials.write("key: value\nbad")

    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidContentError) do
      @credentials.config
    end
  end

  test "raises helpful error when validating invalid content" do
    @credentials.write("key: value\nbad")

    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidContentError) do
      @credentials.validate!
    end
  end

  test "raises helpful error when loading invalid content with unsupported keys" do
    @credentials.write("42: value")

    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidKeyError, match: /Key '42' is invalid, it must respond to '#to_sym' from configuration in '#{@credentials_config_path}'./) do
      @credentials.config
    end

    @credentials.write("42.0: value")
    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidKeyError, match: /Key '42.0' is invalid, it must respond to '#to_sym' from configuration in '#{@credentials_config_path}'./) do
      @credentials.config
    end

    @credentials.write("Off: value")
    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidKeyError, match: /Key 'false' is invalid, it must respond to '#to_sym' from configuration in '#{@credentials_config_path}'./) do
      @credentials.config
    end
  end

  test "raises helpful error when validating invalid content with unsupported keys" do
    @credentials.write("42: value")

    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidKeyError, match: /Key '42' is invalid, it must respond to '#to_sym' from configuration in '#{@credentials_config_path}'./) do
      @credentials.validate!
    end

    @credentials.write("42.0: value")
    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidKeyError, match: /Key '42.0' is invalid, it must respond to '#to_sym' from configuration in '#{@credentials_config_path}'./) do
      @credentials.validate!
    end

    @credentials.write("Off: value")
    assert_raise(ActiveSupport::EncryptedConfiguration::InvalidKeyError, match: /Key 'false' is invalid, it must respond to '#to_sym' from configuration in '#{@credentials_config_path}'./) do
      @credentials.validate!
    end
  end

  test "raises key error when accessing config via bang method" do
    assert_raise(KeyError) { @credentials.something! }
  end

  test "inspect does not show unencrypted attributes" do
    secret = "something secret"
    @credentials.write({ secret: secret }.to_yaml)
    @credentials.config

    assert_no_match(/#{secret}/, @credentials.inspect)
    assert_match(/\A#<ActiveSupport::EncryptedConfiguration:0x[0-9a-f]+>\z/, @credentials.inspect)
  end
end
