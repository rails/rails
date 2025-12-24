# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/dot_env_configuration"

class DotEnvConfigurationTest < ActiveSupport::TestCase
  setup do
    @tmpdir = Dir.mktmpdir("dotenv-")
    @env_file_path = File.join(@tmpdir, ".env")
  end

  teardown do
    FileUtils.rm_rf @tmpdir
  end

  test "require key" do
    write_env_file("ONE" => "1")
    assert_equal "1", @config.require(:one)
  end

  test "require multiword key" do
    write_env_file("ONE_MORE" => "1")
    assert_equal "1", @config.require(:one_more)
  end

  test "require missing key raises key error" do
    write_env_file({})
    assert_raises(KeyError) do
      @config.require(:gone)
    end
  end

  test "require missing multiword key raises key error" do
    write_env_file({})
    assert_raises(KeyError) do
      @config.require(:gone, :missing)
    end
  end

  test "optional missing key returns nil" do
    write_env_file({})
    assert_nil @config.option(:two_is_not_here)
  end

  test "optional missing multiword key returns nil" do
    write_env_file({})
    assert_nil @config.option(:two_is_not_here, :nor_here)
  end

  test "optional missing key with default value returns default" do
    write_env_file({})
    assert_equal "there", @config.option(:two_is_not_here, default: "there")
  end

  test "optional missing key with default block returns default" do
    write_env_file({})
    assert_equal "there", @config.option(:two_is_not_here, default: -> { "there" })
  end

  test "optional missing key with default block returning false returns false" do
    write_env_file({})
    assert_equal false, @config.option(:missing, default: -> { false })
  end

  test "optional missing key with default block returning nil returns nil" do
    write_env_file({})
    assert_nil @config.option(:missing, default: -> { nil })
  end

  test "optional present key with default block returns value without triggering default" do
    write_env_file("EXISTS" => "value")
    called = false
    assert_equal "value", @config.option(:exists, default: -> { called = true; "default" })
    assert_equal false, called
  end

  test "cached reads can be reloaded" do
    write_env_file("ONE" => "1")
    assert_equal "1", @config.require(:one)

    File.write(@env_file_path, "ONE=2")
    assert_equal "1", @config.require(:one)

    @config.reload
    assert_equal "2", @config.require(:one)
  end

  test "parses double quoted values" do
    write_env_file_raw('MESSAGE="hello world"')
    assert_equal "hello world", @config.require(:message)
  end

  test "parses single quoted values" do
    write_env_file_raw("MESSAGE='hello world'")
    assert_equal "hello world", @config.require(:message)
  end

  test "parses escaped newlines in double quoted values" do
    write_env_file_raw('MESSAGE="hello\nworld"')
    assert_equal "hello\nworld", @config.require(:message)
  end

  test "ignores comment lines" do
    write_env_file_raw("# This is a comment\nONE=1")
    assert_equal "1", @config.require(:one)
  end

  test "ignores empty lines" do
    write_env_file_raw("ONE=1\n\nTWO=2")
    assert_equal "1", @config.require(:one)
    assert_equal "2", @config.require(:two)
  end

  test "handles nested keys with double underscore" do
    write_env_file_raw("DATABASE__HOST=localhost")
    assert_equal "localhost", @config.require(:database, :host)
  end

  test "returns empty hash when file does not exist" do
    @config = ActiveSupport::DotEnvConfiguration.new(File.join(@tmpdir, "nonexistent.env"))
    assert_nil @config.option(:anything)
  end

  test "returns empty hash when no path given and Rails is not defined" do
    @config = ActiveSupport::DotEnvConfiguration.new
    assert_nil @config.option(:anything)
  end

  private
    def write_env_file(attributes)
      write_env_file_raw(attributes.map { |key, value| "#{key}=#{value}" }.join("\n"))
    end

    def write_env_file_raw(content)
      File.write(@env_file_path, content)
      @config = ActiveSupport::DotEnvConfiguration.new(@env_file_path)
    end
end
