require 'test_helper'

class WorkerTest < ActiveSupport::TestCase
  class Receiver
    attr_accessor :last_action

    def run
      @last_action = :run
    end

    def process(message)
      @last_action =  [ :process, message ]
    end

    def connection
    end
  end

  setup do
    Celluloid.boot

    @worker = ActionCable::Server::Worker.new
    @receiver = Receiver.new
  end

  teardown do
    @receiver.last_action = nil
  end

  test "invoke" do
    @worker.invoke @receiver, :run
    assert_equal :run, @receiver.last_action
  end

  test "invoke with arguments" do
    @worker.invoke @receiver, :process, "Hello"
    assert_equal [ :process, "Hello" ], @receiver.last_action
  end

  test "running periodic timers with a proc" do
    @worker.run_periodic_timer @receiver, @receiver.method(:run)
    assert_equal :run, @receiver.last_action
  end

  test "running periodic timers with a method" do
    @worker.run_periodic_timer @receiver, :run
    assert_equal :run, @receiver.last_action
  end
end
