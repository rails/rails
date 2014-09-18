require 'helper'

class AdapterTest < ActiveSupport::TestCase
  test "should load #{ENV['AJADAPTER']} adapter" do
    ActiveJob::Base.queue_adapter = ENV['AJADAPTER'].to_sym
    assert_equal ActiveJob::Base.queue_adapter, "active_job/queue_adapters/#{ENV['AJADAPTER']}_adapter".classify.constantize
  end

  test 'should allow overriding the queue_adapter at the child class level without affecting the parent or its sibling' do

    base_queue_adapter = ActiveJob::Base.queue_adapter

    class ChildJobOne < ActiveJob::Base
      self.queue_adapter = :sucker_punch
    end
    assert_equal ActiveJob::QueueAdapters::SuckerPunchAdapter, ChildJobOne.queue_adapter

    class ChildJobTwo < ActiveJob::Base
      self.queue_adapter = :sneakers
    end
    assert_equal ActiveJob::QueueAdapters::SneakersAdapter, ChildJobTwo.queue_adapter

    assert_equal ActiveJob::QueueAdapters::SuckerPunchAdapter, ChildJobOne.queue_adapter, "ChildJobOne's queue adapter should remain unchanged"
    assert_equal base_queue_adapter, ActiveJob::Base.queue_adapter, "ActiveJob::Base's queue adapter should remain unchanged"

  end
end
