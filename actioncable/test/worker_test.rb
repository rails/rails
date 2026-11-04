# frozen_string_literal: true

require "test_helper"

class WorkerTest < ActionCable::TestCase
  class Receiver
    attr_accessor :last_action

    def run
      @last_action = :run
    end

    def process(message)
      @last_action = [ :process, message ]
    end

    def record(log, entry, delay = 0)
      sleep delay
      log << entry
    end

    def connection
      self
    end

    def logger
      # Impersonating a connection requires a TaggedLoggerProxy'ied logger.
      inner_logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
      ActionCable::Server::TaggedLoggerProxy.new(inner_logger, tags: [])
    end
  end

  setup do
    @worker = ActionCable::Server::Worker.new
    @receiver = Receiver.new
  end

  teardown do
    @receiver.last_action = nil
  end

  test "invoke" do
    @worker.invoke @receiver, :run, connection: @receiver.connection
    assert_equal :run, @receiver.last_action
  end

  test "work queued behind a serialized job still runs after halt" do
    serial = Concurrent::SerializedExecutionDelegator.new(@worker.executor)
    log = Concurrent::Array.new

    @worker.async_invoke @receiver, :record, log, :running, 0.1, executor: serial
    @worker.async_invoke @receiver, :record, log, :queued, executor: serial
    @worker.halt

    assert_not @worker.async_invoke(@receiver, :record, log, :posted_after_halt, executor: serial)
    assert @worker.executor.wait_for_termination(2)
    assert_equal [ :running, :queued ], log
  end

  test "invoke with arguments" do
    @worker.invoke @receiver, :process, "Hello", connection: @receiver.connection
    assert_equal [ :process, "Hello" ], @receiver.last_action
  end
end
