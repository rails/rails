require 'abstract_unit'
require 'active_support/queueing'

module ActiveSupport
  class ContainerTest < ActiveSupport::TestCase
    def test_delegates_to_default
      q         = Queue.new
      container = QueueContainer.new q
      job       = Object.new

      container.push job
      assert_equal job, q.pop
    end

    def test_access_default
      q         = Queue.new
      container = QueueContainer.new q
      assert_equal q, container[:default]
    end

    def test_assign_queue
      container = QueueContainer.new Object.new
      q         = Object.new
      container[:foo] = q
      assert_equal q, container[:foo]
    end
  end
end
