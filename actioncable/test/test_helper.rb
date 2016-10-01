require "action_cable"
require "active_support/testing/autorun"

require "puma"
require "mocha/setup"
require "rack/mock"

begin
  require "byebug"
rescue LoadError
end

# Require all the stubs and models
Dir[File.dirname(__FILE__) + "/stubs/*.rb"].each { |file| require file }

if ENV["FAYE"].present?
  require "faye/websocket"
  class << Faye::WebSocket
    remove_method :ensure_reactor_running

    # We don't want Faye to start the EM reactor in tests because it makes testing much harder.
    # We want to be able to start and stop EM loop in tests to make things simpler.
    def ensure_reactor_running
      # no-op
    end
  end
end

module EventMachineConcurrencyHelpers
  def wait_for_async
    EM.run_deferred_callbacks
  end

  def run_in_eventmachine
    failure = nil
    EM.run do
      begin
        yield
      rescue => ex
        failure = ex
      ensure
        wait_for_async
        EM.stop if EM.reactor_running?
      end
    end
    raise failure if failure
  end
end

module ConcurrentRubyConcurrencyHelpers
  def wait_for_async
    wait_for_executor Concurrent.global_io_executor
  end

  def run_in_eventmachine
    yield
    wait_for_async
  end
end

class ActionCable::TestCase < ActiveSupport::TestCase
  if ENV["FAYE"].present?
    include EventMachineConcurrencyHelpers
  else
    include ConcurrentRubyConcurrencyHelpers
  end

  def wait_for_executor(executor)
    # do not wait forever, wait 2s
    timeout = 2
    until executor.completed_task_count == executor.scheduled_task_count
      sleep 0.1
      timeout -= 0.1
      raise "Executor could not complete all tasks in 2 seconds" unless timeout > 0
    end
  end
end
