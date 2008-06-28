require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class StateMachineSubject
  include ActiveModel::StateMachine

  state_machine do
    state :open,   :exit => :exit
    state :closed, :enter => :enter
    
    #event :close, :success => :success_callback do
    #  transitions :to => :closed, :from => [:open]
    #end
    #
    #event :null do
    #  transitions :to => :closed, :from => [:open], :guard => :always_false
    #end
  end

  state_machine :bar do
    state :read
    state :ended

    #event :foo do
    #  transitions :to => :ended, :from => [:read]
    #end
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
 
  #test 'should define an event! inance method' do
  #  assert @foo.respond_to?(:close!)
  #end
end
 
class StateMachineInitialStatesTest < ActiveModel::TestCase
  def setup
    @foo = StateMachineSubject.new
  end
 
  test 'should set the initial state' do
    assert_equal :open, @foo.current_state
  end
 
  #test '#open? should be initially true' do
  #  @foo.open?.should be_true
  #end
  #
  #test '#closed? should be initially false' do
  #  @foo.closed?.should be_false
  #end
 
  test 'should use the first state defined if no initial state is given' do
    assert_equal :read, @foo.current_state(:bar)
  end
end
# 
#describe AASM, '- event firing with persistence' do
#  it 'should fire the Event' do
#    foo = Foo.new
# 
#    Foo.aasm_events[:close].should_receive(:fire).with(foo)
#    foo.close!
#  end
# 
#  it 'should update the current state' do
#    foo = Foo.new
#    foo.close!
# 
#    foo.aasm_current_state.should == :closed
#  end
# 
#  it 'should call the success callback if one was provided' do
#    foo = Foo.new
# 
#    foo.should_receive(:success_callback)
# 
#    foo.close!
#  end
# 
#  it 'should attempt to persist if aasm_write_state is defined' do
#    foo = Foo.new
#    
#    def foo.aasm_write_state
#    end
# 
#    foo.should_receive(:aasm_write_state)
# 
#    foo.close!
#  end
#end
# 
#describe AASM, '- event firing without persistence' do
#  it 'should fire the Event' do
#    foo = Foo.new
# 
#    Foo.aasm_events[:close].should_receive(:fire).with(foo)
#    foo.close
#  end
# 
#  it 'should update the current state' do
#    foo = Foo.new
#    foo.close
# 
#    foo.aasm_current_state.should == :closed
#  end
# 
#  it 'should attempt to persist if aasm_write_state is defined' do
#    foo = Foo.new
#    
#    def foo.aasm_write_state
#    end
# 
#    foo.should_receive(:aasm_write_state_without_persistence)
# 
#    foo.close
#  end
#end
# 
#describe AASM, '- persistence' do
#  it 'should read the state if it has not been set and aasm_read_state is defined' do
#    foo = Foo.new
#    def foo.aasm_read_state
#    end
# 
#    foo.should_receive(:aasm_read_state)
# 
#    foo.aasm_current_state
#  end
#end
# 
#describe AASM, '- getting events for a state' do
#  it '#aasm_events_for_current_state should use current state' do
#    foo = Foo.new
#    foo.should_receive(:aasm_current_state)
#    foo.aasm_events_for_current_state
#  end
# 
#  it '#aasm_events_for_current_state should use aasm_events_for_state' do
#    foo = Foo.new
#    foo.stub!(:aasm_current_state).and_return(:foo)
#    foo.should_receive(:aasm_events_for_state).with(:foo)
#    foo.aasm_events_for_current_state
#  end
#end
# 
#describe AASM, '- event callbacks' do
#  it 'should call aasm_event_fired if defined and successful for bang fire' do
#    foo = Foo.new
#    def foo.aasm_event_fired(from, to)
#    end
# 
#    foo.should_receive(:aasm_event_fired)
# 
#    foo.close!
#  end
# 
#    it 'should call aasm_event_fired if defined and successful for non-bang fire' do
#    foo = Foo.new
#    def foo.aasm_event_fired(from, to)
#    end
# 
#    foo.should_receive(:aasm_event_fired)
# 
#    foo.close
#  end
# 
#  it 'should call aasm_event_failed if defined and transition failed for bang fire' do
#    foo = Foo.new
#    def foo.aasm_event_failed(event)
#    end
# 
#    foo.should_receive(:aasm_event_failed)
# 
#    foo.null!
#  end
# 
#  it 'should call aasm_event_failed if defined and transition failed for non-bang fire' do
#    foo = Foo.new
#    def foo.aasm_event_failed(event)
#    end
# 
#    foo.should_receive(:aasm_event_failed)
# 
#    foo.null
#  end
#end
# 
#describe AASM, '- state actions' do
#  it "should call enter when entering state" do
#    foo = Foo.new
#    foo.should_receive(:enter)
# 
#    foo.close
#  end
# 
#  it "should call exit when exiting state" do
#    foo = Foo.new
#    foo.should_receive(:exit)
# 
#    foo.close
#  end
#end
# 
# 
class StateMachineInheritanceTest < ActiveModel::TestCase
  test "should have the same states as it's parent" do
    assert_equal StateMachineSubject.state_machine.states, StateMachineSubjectSubclass.state_machine.states
  end
 
  #test "should have the same events as it's parent" do
  #  StateMachineSubjectSubclass.aasm_events.should == Bar.aasm_events
  #end
end
# 
# 
#class ChetanPatil
#  include AASM
#  aasm_initial_state :sleeping
#  aasm_state :sleeping
#  aasm_state :showering
#  aasm_state :working
#  aasm_state :dating
# 
#  aasm_event :wakeup do
#    transitions :from => :sleeping, :to => [:showering, :working]
#  end
# 
#  aasm_event :dress do
#    transitions :from => :sleeping, :to => :working, :on_transition => :wear_clothes
#    transitions :from => :showering, :to => [:working, :dating], :on_transition => Proc.new { |obj, *args| obj.wear_clothes(*args) }
#  end
# 
#  def wear_clothes(shirt_color, trouser_type)
#  end
#end
# 
# 
#describe ChetanPatil do
#  it 'should transition to specified next state (sleeping to showering)' do
#    cp = ChetanPatil.new
#    cp.wakeup! :showering
#    
#    cp.aasm_current_state.should == :showering
#  end
# 
#  it 'should transition to specified next state (sleeping to working)' do
#    cp = ChetanPatil.new
#    cp.wakeup! :working
# 
#    cp.aasm_current_state.should == :working
#  end
# 
#  it 'should transition to default (first or showering) state' do
#    cp = ChetanPatil.new
#    cp.wakeup!
# 
#    cp.aasm_current_state.should == :showering
#  end
# 
#  it 'should transition to default state when on_transition invoked' do
#    cp = ChetanPatil.new
#    cp.dress!(nil, 'purple', 'dressy')
# 
#    cp.aasm_current_state.should == :working
#  end
# 
#  it 'should call on_transition method with args' do
#    cp = ChetanPatil.new
#    cp.wakeup! :showering
# 
#    cp.should_receive(:wear_clothes).with('blue', 'jeans')
#    cp.dress! :working, 'blue', 'jeans'
#  end
# 
#  it 'should call on_transition proc' do
#    cp = ChetanPatil.new
#    cp.wakeup! :showering
# 
#    cp.should_receive(:wear_clothes).with('purple', 'slacks')
#    cp.dress!(:dating, 'purple', 'slacks')
#  end
#end