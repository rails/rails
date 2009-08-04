require 'cases/helper'
require 'models/traffic_light'

class StateMachineTest < ActiveRecord::TestCase
  def setup
    @light = TrafficLight.create!
  end

  test "states initial state" do
    assert @light.off?
    assert_equal :off, @light.current_state
  end

  test "transition to a valid state" do
    @light.reset
    assert @light.red?
    assert_equal :red, @light.current_state

    @light.green_on
    assert @light.green?
    assert_equal :green, @light.current_state
  end

  test "transition does not persist state" do
    @light.reset
    assert_equal :red, @light.current_state
    @light.reload
    assert_equal "off", @light.state
  end

  test "transition does persists state" do
    @light.reset!
    assert_equal :red, @light.current_state
    @light.reload
    assert_equal "red", @light.state
  end

  test "transition to an invalid state" do
    assert_raise(ActiveModel::StateMachine::InvalidTransition) { @light.yellow_on }
    assert_equal :off, @light.current_state
  end
end
