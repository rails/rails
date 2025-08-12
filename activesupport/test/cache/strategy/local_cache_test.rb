# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require "active_support/core_ext/object/with"

module ActiveSupport
  module Cache
    module Strategy
      class LocalCacheTest < ActiveSupport::TestCase
        test "sets and restores LocalCache when re-entering the executor" do
          ActiveSupport::ExecutionContext.with(nestable: true) do
            cache = Cache::NullStore.new

            # simulate executor hooks from active_support/railtie.rb
            executor = Class.new(ActiveSupport::Executor)
            executor.to_run do
              ActiveSupport::ExecutionContext.push
            end
            executor.to_complete do
              ActiveSupport::ExecutionContext.pop
            end
            cache.install_executor_hooks(executor)

            cache.write("dev null", 1)
            assert_nil cache.read("dev null")

            cache.with_local_cache do
              assert_nil cache.read("dev null")

              cache.write("cached locally", 2)
              assert_equal 2, cache.read("cached locally")

              executor.wrap do
                assert_nil cache.read("cached locally")

                cache.write("nested cache", 3)
                assert_equal 3, cache.read("nested cache")
              end

              assert_nil cache.read("nested cache")
              assert_equal 2, cache.read("cached locally")
            end

            assert_nil cache.read("cached locally")
          end
        end
      end
    end
  end
end
