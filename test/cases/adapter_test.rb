require 'helper'

class AdapterTest < ActiveSupport::TestCase
  setup    { @old_adapter = ActiveJob::Base.queue_adapter }
  teardown { ActiveJob::Base.queue_adapter = @old_adapter }

  test 'should load inline adapter' do
    ActiveJob::Base.queue_adapter = :inline
    assert_equal ActiveJob::QueueAdapters::InlineAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Delayed Job adapter' do
    ActiveJob::Base.queue_adapter = :delayed_job
    assert_equal ActiveJob::QueueAdapters::DelayedJobAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Que adapter' do
    ActiveJob::Base.queue_adapter = :que
    assert_equal ActiveJob::QueueAdapters::QueAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Queue Classic adapter' do
    ActiveJob::Base.queue_adapter = :queue_classic
    assert_equal ActiveJob::QueueAdapters::QueueClassicAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Resque adapter' do
    ActiveJob::Base.queue_adapter = :resque
    assert_equal ActiveJob::QueueAdapters::ResqueAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Sidekiq adapter' do
    ActiveJob::Base.queue_adapter = :sidekiq
    assert_equal ActiveJob::QueueAdapters::SidekiqAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Sucker Punch adapter' do
    ActiveJob::Base.queue_adapter = :sucker_punch
    assert_equal ActiveJob::QueueAdapters::SuckerPunchAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Sneakers adapter' do
    ActiveJob::Base.queue_adapter = :sneakers
    assert_equal ActiveJob::QueueAdapters::SneakersAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load Backburner adapter' do
    ActiveJob::Base.queue_adapter = :backburner
    assert_equal ActiveJob::QueueAdapters::BackburnerAdapter, ActiveJob::Base.queue_adapter
  end
end
