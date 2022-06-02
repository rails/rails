# frozen_string_literal: true

require "cases/helper"
require "models/person"
require "action_dispatch"

module ActiveRecord
  class ShardSelectorTest < ActiveRecord::TestCase
    def test_middleware_locks_to_shard_by_default
      middleware = ActiveRecord::Middleware::ShardSelector.new(lambda { |env|
        assert_predicate ActiveRecord::Base, :shard_swapping_prohibited?
        [200, {}, ["body"]]
      }, ->(*) { :shard_one })

      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
    end

    def test_middleware_can_turn_off_lock_option
      middleware = ActiveRecord::Middleware::ShardSelector.new(lambda { |env|
        assert_not_predicate ActiveRecord::Base, :shard_swapping_prohibited?
        [200, {}, ["body"]]
      }, ->(*) { :shard_one }, { lock: false })

      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
    end

    def test_middleware_can_change_shards
      middleware = ActiveRecord::Middleware::ShardSelector.new(lambda { |env|
        assert ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
        [200, {}, ["body"]]
      }, ->(*) { :shard_one })

      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
    end

    def test_middleware_can_handle_string_shards
      middleware = ActiveRecord::Middleware::ShardSelector.new(lambda { |env|
        assert ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
        [200, {}, ["body"]]
      }, ->(*) { "shard_one" })

      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
    end
  end
end
