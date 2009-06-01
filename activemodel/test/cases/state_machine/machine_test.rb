require 'cases/helper'

class MachineTestSubject
  include ActiveModel::StateMachine

  state_machine do
    state :open
    state :closed
  end

  state_machine :initial => :foo do
    event :shutdown do
      transitions :from => :open, :to => :closed
    end

    event :timeout do
      transitions :from => :open, :to => :closed
    end
  end

  state_machine :extra, :initial => :bar do
  end
end

class StateMachineMachineTest < ActiveModel::TestCase
  test "allows reuse of existing machines" do
    assert_equal 2, MachineTestSubject.state_machines.size
  end

  test "sets #initial_state from :initial option" do
    assert_equal :bar, MachineTestSubject.state_machine(:extra).initial_state
  end

  test "accesses non-default state machine" do
    assert_kind_of ActiveModel::StateMachine::Machine, MachineTestSubject.state_machine(:extra)
  end

  test "finds events for given state" do
    events = MachineTestSubject.state_machine.events_for(:open)
    assert events.include?(:shutdown)
    assert events.include?(:timeout)
  end
end
