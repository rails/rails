# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class DatabaseConfigurations
    class HashConfigTest < ActiveRecord::TestCase
      def test_pool_default_when_nil
        config = HashConfig.new("default_env", "primary", pool: nil)
        assert_equal 5, config.pool
      end

      def test_pool_overrides_with_value
        config = HashConfig.new("default_env", "primary", pool: "0")
        assert_equal 0, config.pool
      end

      def test_when_no_pool_uses_default
        config = HashConfig.new("default_env", "primary", {})
        assert_equal 5, config.pool
      end

      def test_checkout_timeout_default_when_nil
        config = HashConfig.new("default_env", "primary", checkout_timeout: nil)
        assert_equal 5.0, config.checkout_timeout
      end

      def test_checkout_timeout_overrides_with_value
        config = HashConfig.new("default_env", "primary", checkout_timeout: "0")
        assert_equal 0.0, config.checkout_timeout
      end

      def test_when_no_checkout_timeout_uses_default
        config = HashConfig.new("default_env", "primary", {})
        assert_equal 5.0, config.checkout_timeout
      end

      def test_reaping_frequency_default_when_nil
        config = HashConfig.new("default_env", "primary", reaping_frequency: nil)
        assert_nil config.reaping_frequency
      end

      def test_reaping_frequency_overrides_with_value
        config = HashConfig.new("default_env", "primary", reaping_frequency: "0")
        assert_equal 0.0, config.reaping_frequency
      end

      def test_when_no_reaping_frequency_uses_default
        config = HashConfig.new("default_env", "primary", {})
        assert_equal 60.0, config.reaping_frequency
      end

      def test_idle_timeout_default_when_nil
        config = HashConfig.new("default_env", "primary", idle_timeout: nil)
        assert_nil config.idle_timeout
      end

      def test_idle_timeout_overrides_with_value
        config = HashConfig.new("default_env", "primary", idle_timeout: "1")
        assert_equal 1.0, config.idle_timeout
      end

      def test_when_no_idle_timeout_uses_default
        config = HashConfig.new("default_env", "primary", {})
        assert_equal 300.0, config.idle_timeout
      end

      def test_idle_timeout_nil_when_less_than_or_equal_to_zero
        config = HashConfig.new("default_env", "primary", idle_timeout: "0")
        assert_nil config.idle_timeout
      end

      def test_default_schema_dump_value
        config = HashConfig.new("default_env", "primary", schema_dump: nil)
        assert_equal config.schema_dump, true
      end

      def test_custom_schema_dump_value
        config = HashConfig.new("default_env", "primary", schema_dump: true)
        assert_equal config.schema_dump, true
      end

      def test_custom_schema_dump_value
        config = HashConfig.new("default_env", "primary", schema_dump: false)
        assert_equal config.schema_dump, false
      end
    end
  end
end
