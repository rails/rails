# frozen_string_literal: true

require "cases/helper"
require "models/person"
require "action_dispatch"
require "concurrent/atomic/count_down_latch"

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

    def test_thread_sharing_the_execution_state_keeps_the_shard_after_the_middleware_returns
      state_shared = Concurrent::CountDownLatch.new
      middleware_returned = Concurrent::CountDownLatch.new
      thread = nil

      middleware = ActiveRecord::Middleware::ShardSelector.new(lambda { |env|
        # Like ActionController::Live, keep working on another thread after
        # the response has been returned.
        context = ActiveSupport::IsolatedExecutionState.context
        thread = Thread.new do
          ActiveSupport::IsolatedExecutionState.share_with(context) do
            state_shared.count_down
            middleware_returned.wait

            ActiveRecord::Base.current_shard
          end
        end

        state_shared.wait
        [200, {}, ["body"]]
      }, ->(*) { :shard_one })

      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
      middleware_returned.count_down

      assert_equal :shard_one, thread.value
    ensure
      middleware_returned.count_down
      thread&.join
    end

    def test_middleware_can_do_granular_database_connection_switching
      klass = Class.new(ActiveRecord::Base) do |k|
        class << self
          attr_reader :connected_to_shard

          def connected_to(shard:)
            @connected_to_shard = shard
            yield
          end

          def prohibit_shard_swapping(...)
            yield
          end

          def connected_to?(role: nil, shard:)
            @connected_to_shard.to_sym == shard.to_sym
          end
        end
      end
      Object.const_set :ShardSelectorTestModel, klass

      middleware = ActiveRecord::Middleware::ShardSelector.new(lambda { |env|
        assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
        assert klass.connected_to?(role: :writing, shard: :shard_one)
        [200, {}, ["body"]]
      }, ->(*) { :shard_one }, { class_name: "ShardSelectorTestModel" })

      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
      assert_equal(:shard_one, klass.connected_to_shard)
    ensure
      Object.send(:remove_const, :ShardSelectorTestModel)
    end
  end
end
