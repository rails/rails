require 'helper'
require 'jobs/inheritable_jobs'

class AdapterTest < ActiveSupport::TestCase
  test "should load #{ENV['AJADAPTER']} adapter" do
    ActiveJob::Base.queue_adapter = ENV['AJADAPTER'].to_sym
    assert_equal ActiveJob::Base.queue_adapter, "active_job/queue_adapters/#{ENV['AJADAPTER']}_adapter".classify.constantize
  end

  test 'should allow overriding the queue_adapter at the child class level without affecting the parent or its sibling' do

    base_queue_adapter = ActiveJob::Base.queue_adapter

    assert_not_equal ActiveJob::Base.queue_adapter, Child1Job.queue_adapter
    assert_equal ActiveJob::QueueAdapters::TestAdapter, Child1Job.queue_adapter

    assert_equal ActiveJob::QueueAdapters::InlineAdapter, Child2Job.queue_adapter

    assert_equal ActiveJob::QueueAdapters::TestAdapter, Child1Job.queue_adapter, "ChildJobOne's queue adapter should remain unchanged"
    assert_equal base_queue_adapter, ActiveJob::Base.queue_adapter, "ActiveJob::Base's queue adapter should remain unchanged"

    assert_equal ActiveJob::Base.queue_adapter, Child3Job.queue_adapter, 'should use the default queue_adapter'
    assert_equal Child1Job.queue_adapter, GrandChild1Job.queue_adapter, 'should properly inherit queue_adapter from the inheritance chain'
    assert_equal Child2Job.queue_adapter, GrandChild2Job.queue_adapter, 'should properly inherit queue_adapter from the inheritance chain'
  end
end

