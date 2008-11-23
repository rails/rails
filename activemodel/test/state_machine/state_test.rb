require 'test_helper'

class StateTestSubject
  include ActiveModel::StateMachine

  state_machine do
  end
end

class StateTest < ActiveModel::TestCase
  def setup
    @state_name = :astate
    @machine = StateTestSubject.state_machine
    @options = { :crazy_custom_key => 'key', :machine => @machine }
  end

  def new_state(options={})
    ActiveModel::StateMachine::State.new(@state_name, @options.merge(options))
  end

  test 'sets the name' do
    assert_equal :astate, new_state.name
  end

  test 'sets the display_name from name' do
    assert_equal "Astate", new_state.display_name
  end

  test 'sets the display_name from options' do
    assert_equal "A State", new_state(:display => "A State").display_name
  end
  
  test 'sets the options and expose them as options' do
    @options.delete(:machine)
    assert_equal @options, new_state.options
  end

  test 'equals a symbol of the same name' do
    assert_equal new_state, :astate
  end

  test 'equals a State of the same name' do
    assert_equal new_state, new_state
  end

  test 'should send a message to the record for an action if the action is present as a symbol' do
    state = new_state(:entering => :foo)

    record = stub
    record.expects(:foo)

    state.call_action(:entering, record)
  end

  test 'should send a message to the record for an action if the action is present as a string' do
    state = new_state(:entering => 'foo')

    record = stub
    record.expects(:foo)

    state.call_action(:entering, record)
  end

  test 'should call a proc, passing in the record for an action if the action is present' do
    state = new_state(:entering => Proc.new {|r| r.foobar})

    record = stub
    record.expects(:foobar)
  
    state.call_action(:entering, record)
  end
end
