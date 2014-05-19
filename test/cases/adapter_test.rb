require 'helper'

class AdapterTest < ActiveSupport::TestCase
  def setup
    @old_adapter = ActiveJob::Base.queue_adapter
  end

  test 'should load inline adapter' do
    ActiveJob::Base.queue_adapter = :inline
    assert_equal ActiveJob::QueueAdapters::InlineAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load resque adapter' do
    ActiveJob::Base.queue_adapter = :resque
    assert_equal ActiveJob::QueueAdapters::ResqueAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load sidekiq adapter' do
    ActiveJob::Base.queue_adapter = :sidekiq
    assert_equal ActiveJob::QueueAdapters::SidekiqAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load sucker punch adapter' do
    ActiveJob::Base.queue_adapter = :sucker_punch
    assert_equal ActiveJob::QueueAdapters::SuckerPunchAdapter, ActiveJob::Base.queue_adapter
  end

  test 'should load delayed_job adapter' do
    ActiveJob::Base.queue_adapter = :delayed_job
    assert_equal ActiveJob::QueueAdapters::DelayedJobAdapter, ActiveJob::Base.queue_adapter
  end

  def teardown
    ActiveJob::Base.queue_adapter = @old_adapter
  end
end
