require "test_helper"
require_relative "./common"

class EventedRedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest

  def setup
    super

    # em-hiredis is warning-rich
    @previous_verbose, $VERBOSE = $VERBOSE, nil
  end

  def teardown
    super

    # Ensure EM is shut down before we re-enable warnings
    EventMachine.reactor_thread.tap do |thread|
      EventMachine.stop
      thread.join
    end

    $VERBOSE = @previous_verbose
  end

  def cable_config
    { adapter: "evented_redis", url: "redis://127.0.0.1:6379/12" }
  end
end
