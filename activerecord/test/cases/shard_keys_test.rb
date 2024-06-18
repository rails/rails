# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class ShardsKeysTest < ActiveRecord::TestCase
    class UnshardedBase < ActiveRecord::Base
      self.abstract_class = true
    end

    class UnshardedModel < UnshardedBase
    end

    class ShardedBase < ActiveRecord::Base
      self.abstract_class = true
    end

    class ShardedModel < ShardedBase
    end

    def setup
      ActiveRecord::Base.instance_variable_set(:@shard_keys, nil)
      @previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

      config = {
        "default_env" => {
          "primary" => {
            adapter: "sqlite3",
            database: ":memory:"
          },
          "shard_one" => {
            adapter: "sqlite3",
            database: ":memory:"
          },
          "shard_one_reading" => {
            adapter: "sqlite3",
            database: ":memory:"
          },
          "shard_two" => {
            adapter: "sqlite3",
            database: ":memory:"
          },
          "shard_two_reading" => {
            adapter: "sqlite3",
            database: ":memory:"
          },
        }
      }

      @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

      UnshardedBase.connects_to database: { writing: :primary }

      ShardedBase.connects_to shards: {
        shard_one: { writing: :shard_one, reading: :shard_one_reading },
        shard_two: { writing: :shard_two, reading: :shard_two_reading },
      }
    end

    def teardown
      clean_up_connection_handler
      ActiveRecord::Base.configurations = @prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = @previous_env
    end

    def test_connects_to_sets_shard_keys
      assert_empty(ActiveRecord::Base.shard_keys)
      assert_equal([:shard_one, :shard_two], ShardedBase.shard_keys)
    end

    def test_connects_to_sets_shard_keys_for_descendents
      assert_equal(ShardedBase.shard_keys, ShardedModel.shard_keys)
    end

    def test_sharded?
      assert_not ActiveRecord::Base.sharded?
      assert_not UnshardedBase.sharded?
      assert_not UnshardedModel.sharded?

      assert_predicate ShardedBase, :sharded?
      assert_predicate ShardedModel, :sharded?
    end

    def test_connected_to_all_shards
      unsharded_results = UnshardedBase.connected_to_all_shards do
        UnshardedBase.connection_pool.db_config.name
      end

      sharded_results = ShardedBase.connected_to_all_shards do
        ShardedBase.connection_pool.db_config.name
      end

      assert_empty unsharded_results
      assert_equal(["shard_one", "shard_two"], sharded_results)
    end

    def test_connected_to_all_shards_can_switch_each_to_reading_role
      # We teardown the shared connection pool and call .connects_to again
      # because .setup_shared_connection_pool overwrites our reading configs
      # with the writing role configs.
      teardown_shared_connection_pool
      ShardedBase.connects_to shards: {
        shard_one: { writing: :shard_one, reading: :shard_one_reading },
        shard_two: { writing: :shard_two, reading: :shard_two_reading },
      }

      results = ShardedBase.connected_to_all_shards(role: :reading) do
        ShardedBase.connection_pool.db_config.name
      end

      assert_equal(["shard_one_reading", "shard_two_reading"], results)
    end

    def test_connected_to_all_shards_respects_preventing_writes
      assert_not ShardedBase.current_preventing_writes

      results = ShardedBase.connected_to_all_shards(role: :writing, prevent_writes: true) do
        ShardedBase.current_preventing_writes
      end

      assert_equal([true, true], results)
    end
  end
end
