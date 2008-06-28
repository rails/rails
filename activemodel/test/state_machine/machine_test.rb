require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class MachineTestSubject
  include ActiveModel::StateMachine

  state_machine do
  end

  state_machine :initial => :foo do
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
end