# frozen_string_literal: true

require "helper"

class AdapterTest < ActiveSupport::TestCase
  test "should load #{ENV['AJ_ADAPTER']} adapter" do
    assert_equal "active_job/queue_adapters/#{ENV['AJ_ADAPTER']}_adapter".classify, ActiveJob::Base.queue_adapter.class.name
  end

  if adapter_is?(:sidekiq)
    test "sidekiq adapter should be deprecated" do
      before_adapter = ActiveJob::Base.queue_adapter

      msg = <<~MSG.squish
        The built-in `sidekiq` adapter is deprecated and will be removed in Rails 8.2.
        Please upgrade `sidekiq` gem to version 7.3.3 or later to use the `sidekiq` gem's adapter.
      MSG
      assert_deprecated(msg, ActiveJob.deprecator) do
        ActiveJob::Base.queue_adapter = :sidekiq
      end
    ensure
      ActiveJob::Base.queue_adapter = before_adapter
    end
  end

  if adapter_is?(:sneakers)
    test "sneakers adapter should be deprecated" do
      before_adapter = ActiveJob::Base.queue_adapter

      msg = <<~MSG.squish
        The built-in `sneakers` adapter is deprecated and will be removed in Rails 8.1.
        Please migrate from `sneakers` gem to `kicks` gem version 3.1.1 or later to use `ActiveJob` adapter from `kicks`.
      MSG
      assert_deprecated(msg, ActiveJob.deprecator) do
        ActiveJob::Base.queue_adapter = :sneakers
      end

    ensure
      ActiveJob::Base.queue_adapter = before_adapter
    end

    test "sneakers check_adapter should warn" do
      msg = <<~MSG.squish
        The built-in `sneakers` adapter is deprecated and will be removed in Rails 8.1.
        Please migrate from `sneakers` gem to `kicks` gem version 3.1.1 or later to use `ActiveJob` adapter from `kicks`.
      MSG
      assert_deprecated(msg, ActiveJob.deprecator) do
        ActiveJob::Base.queue_adapter.check_adapter
      end
    end
  end
end
