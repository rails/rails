# frozen_string_literal: true

require "test_helper"

class WorkerTest < ActiveSupport::TestCase
  class Receiver
    attr_accessor :last_action

    def run
      @last_action = :run
    end

    def process(message)
      @last_action = [ :process, message ]
    end

    def connection
      self
    end

    def logger
      # Impersonating a connection requires a TaggedLoggerProxy'ied logger.
      inner_logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
      ActionCable::Connection::TaggedLoggerProxy.new(inner_logger, tags: [])
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

  test "invoke with arguments" do
    @worker.invoke @receiver, :process, "Hello", connection: @receiver.connection
    assert_equal [ :process, "Hello" ], @receiver.last_action
  end
end
