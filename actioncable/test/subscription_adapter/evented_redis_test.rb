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
    $VERBOSE = @previous_verbose
  end

  def cable_config
    { adapter: "evented_redis", url: "redis://127.0.0.1:6379/12" }
  end
end
