require "test_helper"
require_relative "./common"
require_relative "./channel_prefix"

class EventedRedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def setup
    assert_deprecated do
      super
    end

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

  def test_slow_eventmachine
    require "eventmachine"
    require "thread"

    lock = Mutex.new

    EventMachine.singleton_class.class_eval do
      alias_method :delayed_initialize_event_machine, :initialize_event_machine
      define_method(:initialize_event_machine) do
        lock.synchronize do
          sleep 0.5
          delayed_initialize_event_machine
        end
      end
    end

    test_basic_broadcast
  ensure
    lock.synchronize do
      EventMachine.singleton_class.class_eval do
        alias_method :initialize_event_machine, :delayed_initialize_event_machine
        remove_method :delayed_initialize_event_machine
      end
    end
  end

  def cable_config
    { adapter: "evented_redis", url: "redis://127.0.0.1:6379/12" }
  end
end
