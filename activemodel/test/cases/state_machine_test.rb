require 'cases/helper'

class StateMachineSubject
  include ActiveModel::StateMachine

  state_machine do
    state :open,   :exit => :exit
    state :closed, :enter => :enter
    
    event :close, :success => :success_callback do
      transitions :to => :closed, :from => [:open]
    end

    event :null do
      transitions :to => :closed, :from => [:open], :guard => :always_false
    end
  end

  state_machine :bar do
    state :read
    state :ended

    event :foo do
      transitions :to => :ended, :from => [:read]
    end
  end

  def always_false
    false
  end
 
  def success_callback
  end
 
  def enter
  end
  def exit
  end
end

class StateMachineSubjectSubclass < StateMachineSubject
end

class StateMachineClassLevelTest < ActiveModel::TestCase
  test 'defines a class level #state_machine method on its including class' do
    assert StateMachineSubject.respond_to?(:state_machine)
  end

  test 'defines a class level #state_machines method on its including class' do
    assert StateMachineSubject.respond_to?(:state_machines)
  end

  test 'class level #state_machine returns machine instance' do
    assert_kind_of ActiveModel::StateMachine::Machine, StateMachineSubject.state_machine
  end

  test 'class level #state_machine returns machine instance with given name' do
    assert_kind_of ActiveModel::StateMachine::Machine, StateMachineSubject.state_machine(:default)
  end

  test 'class level #state_machines returns hash of machine instances' do
    assert_kind_of ActiveModel::StateMachine::Machine, StateMachineSubject.state_machines[:default]
  end

  test "should return a select friendly array of states in the form of [['Friendly name', 'state_name']]" do
    assert_equal [['Open', 'open'], ['Closed', 'closed']], StateMachineSubject.state_machine.states_for_select
  end
end

class StateMachineInstanceLevelTest < ActiveModel::TestCase
  def setup
    @foo = StateMachineSubject.new
  end
 
  test 'defines an accessor for the current state' do
    assert @foo.respond_to?(:current_state)
  end
 
  test 'defines a state querying instance method on including class' do
    assert @foo.respond_to?(:open?)
  end
 
  test 'defines an event! instance method' do
    assert @foo.respond_to?(:close!)
  end
 
  test 'defines an event instance method' do
    assert @foo.respond_to?(:close)
  end
end
 
class StateMachineInitialStatesTest < ActiveModel::TestCase
  def setup
    @foo = StateMachineSubject.new
  end
 
  test 'sets the initial state' do
    assert_equal :open, @foo.current_state
  end
 
  test '#open? should be initially true' do
    assert @foo.open?
  end
  
  test '#closed? should be initially false' do
    assert !@foo.closed?
  end
 
  test 'uses the first state defined if no initial state is given' do
    assert_equal :read, @foo.current_state(:bar)
  end
end
 
class StateMachineEventFiringWithPersistenceTest < ActiveModel::TestCase
  def setup
    @subj = StateMachineSubject.new
  end

  test 'updates the current state' do
    @subj.close!

    assert_equal :closed, @subj.current_state
  end

  test 'fires the Event' do
    @subj.class.state_machine.events[:close].expects(:fire).with(@subj)
    @subj.close!
  end

  test 'calls the success callback if one was provided' do
    @subj.expects(:success_callback)
    @subj.close!
  end

  test 'attempts to persist if write_state is defined' do
    def @subj.write_state
    end

    @subj.expects(:write_state)
    @subj.close!
  end
end

class StateMachineEventFiringWithoutPersistence < ActiveModel::TestCase
  test 'updates the current state' do
    subj = StateMachineSubject.new
    assert_equal :open, subj.current_state
    subj.close
    assert_equal :closed, subj.current_state
  end

  test 'fires the Event' do
    subj = StateMachineSubject.new

    StateMachineSubject.state_machine.events[:close].expects(:fire).with(subj)
    subj.close
  end

  test 'attempts to persist if write_state is defined' do
    subj = StateMachineSubject.new

    def subj.write_state
    end

    subj.expects(:write_state_without_persistence)

    subj.close
  end
end

class StateMachinePersistenceTest < ActiveModel::TestCase
  test 'reads the state if it has not been set and read_state is defined' do
    subj = StateMachineSubject.new
    def subj.read_state
    end

    subj.expects(:read_state).with(StateMachineSubject.state_machine)

    subj.current_state
  end
end

class StateMachineEventCallbacksTest < ActiveModel::TestCase
  test 'should call aasm_event_fired if defined and successful for bang fire' do
    subj = StateMachineSubject.new
    def subj.aasm_event_fired(from, to)
    end

    subj.expects(:event_fired)

    subj.close!
  end

  test 'should call aasm_event_fired if defined and successful for non-bang fire' do
    subj = StateMachineSubject.new
    def subj.aasm_event_fired(from, to)
    end

    subj.expects(:event_fired)

    subj.close
  end

  test 'should call aasm_event_failed if defined and transition failed for bang fire' do
    subj = StateMachineSubject.new
    def subj.event_failed(event)
    end

    subj.expects(:event_failed)

    subj.null!
  end

  test 'should call aasm_event_failed if defined and transition failed for non-bang fire' do
    subj = StateMachineSubject.new
    def subj.aasm_event_failed(event)
    end

    subj.expects(:event_failed)

    subj.null
  end
end

class StateMachineStateActionsTest < ActiveModel::TestCase
  test "calls enter when entering state" do
    subj = StateMachineSubject.new
    subj.expects(:enter)
    subj.close
  end

  test "calls exit when exiting state" do
    subj = StateMachineSubject.new
    subj.expects(:exit)
    subj.close
  end
end

class StateMachineInheritanceTest < ActiveModel::TestCase
  test "has the same states as its parent" do
    assert_equal StateMachineSubject.state_machine.states, StateMachineSubjectSubclass.state_machine.states
  end
 
  test "has the same events as its parent" do
    assert_equal StateMachineSubject.state_machine.events, StateMachineSubjectSubclass.state_machine.events
  end
end

class StateMachineSubject
  state_machine :chetan_patil, :initial => :sleeping do
    state :sleeping
    state :showering
    state :working
    state :dating
 
    event :wakeup do
      transitions :from => :sleeping, :to => [:showering, :working]
    end
 
    event :dress do
      transitions :from => :sleeping, :to => :working, :on_transition => :wear_clothes
      transitions :from => :showering, :to => [:working, :dating], :on_transition => Proc.new { |obj, *args| obj.wear_clothes(*args) }
    end
  end
 
  def wear_clothes(shirt_color, trouser_type)
  end
end

class StateMachineWithComplexTransitionsTest < ActiveModel::TestCase
  def setup
    @subj = StateMachineSubject.new
  end

  test 'transitions to specified next state (sleeping to showering)' do
    @subj.wakeup! :showering
    
    assert_equal :showering, @subj.current_state(:chetan_patil)
  end
 
  test 'transitions to specified next state (sleeping to working)' do
    @subj.wakeup! :working
 
    assert_equal :working, @subj.current_state(:chetan_patil)
  end
 
  test 'transitions to default (first or showering) state' do
    @subj.wakeup!
 
    assert_equal :showering, @subj.current_state(:chetan_patil)
  end
 
  test 'transitions to default state when on_transition invoked' do
    @subj.dress!(nil, 'purple', 'dressy')
 
    assert_equal :working, @subj.current_state(:chetan_patil)
  end

  test 'calls on_transition method with args' do
    @subj.wakeup! :showering

    @subj.expects(:wear_clothes).with('blue', 'jeans')
    @subj.dress! :working, 'blue', 'jeans'
  end

  test 'calls on_transition proc' do
    @subj.wakeup! :showering

    @subj.expects(:wear_clothes).with('purple', 'slacks')
    @subj.dress!(:dating, 'purple', 'slacks')
  end
end
