# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/env_configuration"

class EnvConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = ActiveSupport::EnvConfiguration.new
  end

  test "require key" do
    set_env("ONE" => "1") do
      assert_equal "1", @config.require(:one)
    end
  end

  test "require multiword key" do
    set_env("ONE_MORE" => "1") do
      assert_equal "1", @config.require(:one_more)
    end
  end

  test "reqiure missing key raises key error" do
    assert_raises(KeyError) do
      @config.require(:gone)
    end
  end

  test "reqiure missing multiword key raises key error" do
    assert_raises(KeyError) do
      @config.require(:gone, :missing)
    end
  end

  test "optional missing key returns nil" do
    assert_nil @config.option(:two_is_not_here)
  end

  test "optional missing multiword key returns nil" do
    assert_nil @config.option(:two_is_not_here, :nor_here)
  end

  test "optional missing key with default value returns default" do
    assert_equal "there", @config.option(:two_is_not_here, default: "there")
  end

  test "optional missing key with default block returns default" do
    assert_equal "there", @config.option(:two_is_not_here, default: -> { "there" })
  end

  test "optional missing key with default block returning false returns false" do
    assert_equal false, @config.option(:missing, default: -> { false })
  end

  test "optional missing key with default block returning nil returns nil" do
    assert_nil @config.option(:missing, default: -> { nil })
  end

  test "optional present key with default block returns value without triggering default" do
    set_env("EXISTS" => "value") do
      called = false
      assert_equal "value", @config.option(:exists, default: -> { called = true; "default" })
      assert_equal false, called
    end
  end

  test "cached reads can be reloaded" do
    set_env("ONE" => "1") do
      assert_equal "1", @config.require(:one)

      ENV["ONE"] = "2"
      assert_equal "1", @config.require(:one)

      @config.reload
      assert_equal "2", @config.require(:one)
    end
  end

  test "inspect does not show ENV variable values but shows keys as symbols" do
    secret = "something_secret"
    set_env("SECRET_TOKEN" => secret) do
      assert_no_match(/#{secret}/, @config.inspect)
      assert_match(/keys=.*:secret_token/, @config.inspect)
      assert_match(/\A#<ActiveSupport::EnvConfiguration:0x[0-9a-f]+ keys=\[.*\]>\z/, @config.inspect)
    end
  end

  private
    def set_env(attributes)
      attributes.each do |key, value|
        ENV[key] = value
      end

      @config.reload
      yield
    ensure
      attributes.keys.each do |key|
        ENV.delete(key)
      end
    end
end
