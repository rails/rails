# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class DatabaseConfigurations
    class HashConfigTest < ActiveRecord::TestCase
      def test_pool_default_when_nil
        config = HashConfig.new("default_env", "primary", pool: nil, adapter: "abstract")
        assert_equal 5, config.pool
      end

      def test_pool_overrides_with_value
        config = HashConfig.new("default_env", "primary", pool: "0", adapter: "abstract")
        assert_equal 0, config.pool
      end

      def test_when_no_pool_uses_default
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 5, config.pool
      end

      def test_min_threads_with_value
        config = HashConfig.new("default_env", "primary", min_threads: "1", adapter: "abstract")
        assert_equal 1, config.min_threads
      end

      def test_min_threads_default
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 0, config.min_threads
      end

      def test_max_threads_with_value
        config = HashConfig.new("default_env", "primary", max_threads: "10", adapter: "abstract")
        assert_equal 10, config.max_threads
      end

      def test_max_threads_default_uses_pool_default
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 5, config.pool
        assert_equal 5, config.max_threads
      end

      def test_max_threads_uses_pool_when_set
        config = HashConfig.new("default_env", "primary", pool: 1, adapter: "abstract")
        assert_equal 1, config.pool
        assert_equal 1, config.max_threads
      end

      def test_max_queue_is_pool_multiplied_by_4
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 5, config.max_threads
        assert_equal config.max_threads * 4, config.max_queue
      end

      def test_checkout_timeout_default_when_nil
        config = HashConfig.new("default_env", "primary", checkout_timeout: nil, adapter: "abstract")
        assert_equal 5.0, config.checkout_timeout
      end

      def test_checkout_timeout_overrides_with_value
        config = HashConfig.new("default_env", "primary", checkout_timeout: "0", adapter: "abstract")
        assert_equal 0.0, config.checkout_timeout
      end

      def test_when_no_checkout_timeout_uses_default
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 5.0, config.checkout_timeout
      end

      def test_reaping_frequency_default_when_nil
        config = HashConfig.new("default_env", "primary", reaping_frequency: nil, adapter: "abstract")
        assert_nil config.reaping_frequency
      end

      def test_reaping_frequency_overrides_with_value
        config = HashConfig.new("default_env", "primary", reaping_frequency: "0", adapter: "abstract")
        assert_equal 0.0, config.reaping_frequency
      end

      def test_when_no_reaping_frequency_uses_default
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 60.0, config.reaping_frequency
      end

      def test_idle_timeout_default_when_nil
        config = HashConfig.new("default_env", "primary", idle_timeout: nil, adapter: "abstract")
        assert_nil config.idle_timeout
      end

      def test_idle_timeout_overrides_with_value
        config = HashConfig.new("default_env", "primary", idle_timeout: "1", adapter: "abstract")
        assert_equal 1.0, config.idle_timeout
      end

      def test_when_no_idle_timeout_uses_default
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal 300.0, config.idle_timeout
      end

      def test_idle_timeout_nil_when_less_than_or_equal_to_zero
        config = HashConfig.new("default_env", "primary", idle_timeout: "0", adapter: "abstract")
        assert_nil config.idle_timeout
      end

      def test_default_schema_dump_value
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal "schema.rb", config.schema_dump
      end

      def test_schema_dump_value_set_to_filename
        config = HashConfig.new("default_env", "primary", { schema_dump: "my_schema.rb", adapter: "abstract" })
        assert_equal "my_schema.rb", config.schema_dump
      end

      def test_schema_dump_value_set_to_nil
        config = HashConfig.new("default_env", "primary", { schema_dump: nil, adapter: "abstract" })
        assert_nil config.schema_dump
      end

      def test_schema_dump_value_set_to_false
        config = HashConfig.new("default_env", "primary", { schema_dump: false, adapter: "abstract" })
        assert_nil config.schema_dump
      end

      def test_database_tasks_defaults_to_true
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal true, config.database_tasks?
      end

      def test_database_tasks_overrides_with_value
        config = HashConfig.new("default_env", "primary", database_tasks: false, adapter: "abstract")
        assert_equal false, config.database_tasks?

        config = HashConfig.new("default_env", "primary", database_tasks: "str", adapter: "abstract")
        assert_equal true, config.database_tasks?
      end

      def test_schema_cache_path_default_for_primary
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert_equal "db/schema_cache.yml", config.default_schema_cache_path
      end

      def test_schema_cache_path_default_for_custom_name
        config = HashConfig.new("default_env", "alternate", adapter: "abstract")
        assert_equal "db/alternate_schema_cache.yml", config.default_schema_cache_path
      end

      def test_schema_cache_path_default_for_different_db_dir
        config = HashConfig.new("default_env", "alternate", adapter: "abstract")
        assert_equal "my_db/alternate_schema_cache.yml", config.default_schema_cache_path("my_db")
      end

      def test_schema_cache_path_configuration_hash
        config = HashConfig.new("default_env", "primary", { schema_cache_path: "db/config_schema_cache.yml", adapter: "abstract" })
        assert_equal "db/config_schema_cache.yml", config.schema_cache_path
      end

      def test_lazy_schema_cache_path
        config = HashConfig.new("default_env", "primary", { schema_cache_path: "db/config_schema_cache.yml", adapter: "abstract" })
        assert_equal "db/config_schema_cache.yml", config.lazy_schema_cache_path
      end

      def test_lazy_schema_cache_path_uses_default_if_config_is_not_present
        config = HashConfig.new("default_env", "alternate", { adapter: "abstract" })
        assert_equal "db/alternate_schema_cache.yml", config.lazy_schema_cache_path
      end

      def test_validate_checks_the_adapter_exists
        config = HashConfig.new("default_env", "primary", adapter: "abstract")
        assert config.validate!
        config = HashConfig.new("default_env", "primary", adapter: "potato")
        assert_raises(ActiveRecord::AdapterNotFound) do
          config.validate!
        end
      end

      def test_inspect_does_not_show_secrets
        config = HashConfig.new("default_env", "primary", { adapter: "abstract", password: "hunter2" })
        assert_equal "#<ActiveRecord::DatabaseConfigurations::HashConfig env_name=default_env name=primary adapter_class=ActiveRecord::ConnectionAdapters::AbstractAdapter>", config.inspect
      end

      def test_seeds_defaults_to_primary
        config = HashConfig.new("default_env", "primary", { adapter: "abstract" })
        assert_equal true, config.seeds?

        config = HashConfig.new("default_env", "primary", { adapter: "abstract", seeds: false })
        assert_equal false, config.seeds?

        config = HashConfig.new("default_env", "primary", { adapter: "abstract", seeds: true })
        assert_equal true, config.seeds?

        config = HashConfig.new("default_env", "secondary", { adapter: "abstract" })
        config.stub(:primary?, false) do # primary? will return nil without proper Base.configurations
          assert_equal false, config.seeds?
        end

        config = HashConfig.new("default_env", "secondary", { adapter: "abstract", seeds: false })
        config.stub(:primary?, false) do # primary? will return nil without proper Base.configurations
          assert_equal false, config.seeds?
        end

        config = HashConfig.new("default_env", "secondary", { adapter: "abstract", seeds: true })
        config.stub(:primary?, false) do # primary? will return nil without proper Base.configurations
          assert_equal true, config.seeds?
        end
      end
    end
  end
end
