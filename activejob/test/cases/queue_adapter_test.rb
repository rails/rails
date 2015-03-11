require 'helper'

class QueueAdapterTest < ActiveJob::TestCase
  test 'should forbid nonsense arguments' do
    assert_raises(ArgumentError) { ActiveJob::Base.queue_adapter = Mutex }
    assert_raises(ArgumentError) { ActiveJob::Base.queue_adapter = Mutex.new }
  end

  test 'should warn on passing an adapter class' do
    klass = Class.new do
      def self.name
        'fake'
      end

      def enqueue(*)
      end

      def enqueue_at(*)
      end
    end

    assert_deprecated { ActiveJob::Base.queue_adapter = klass }
  end
end
