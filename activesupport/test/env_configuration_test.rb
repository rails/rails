# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/env_configuration"

class EnvConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = ActiveSupport::EnvConfiguration.new
  end

  test "read key" do
    set_env("ONE" => "1") do
      assert_equal "1", @config[:one]
    end
  end

  test "read multiword key" do
    set_env("ONE_MORE" => "1") do
      assert_equal "1", @config[:one_more]
    end
  end

  test "read missing key" do
    assert_nil @config[:two_is_not_here]
  end

  test "dig nested key" do
    set_env("ONE__MORE" => "more") do
      assert_equal "more", @config.dig(:one, :more)
      assert_nil @config.dig(:one, :missing)
    end
  end

  test "cached reads can be reloaded" do
    set_env("ONE" => "1") do
      assert_equal "1", @config[:one]

      ENV["ONE"] = "2"
      assert_equal "1", @config[:one]

      @config.reload
      assert_equal "2", @config[:one]
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
