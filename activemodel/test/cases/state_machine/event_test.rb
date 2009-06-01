require 'cases/helper'

class EventTest < ActiveModel::TestCase
  def setup
    @state_name = :close_order
    @success = :success_callback
  end

  def new_event
    @event = ActiveModel::StateMachine::Event.new(nil, @state_name, {:success => @success}) do
      transitions :to => :closed, :from => [:open, :received]
    end
  end

  test 'should set the name' do
    assert_equal @state_name, new_event.name
  end

  test 'should set the success option' do
    assert_equal @success, new_event.success
  end

  test 'should create StateTransitions' do
    ActiveModel::StateMachine::StateTransition.expects(:new).with(:to => :closed, :from => :open)
    ActiveModel::StateMachine::StateTransition.expects(:new).with(:to => :closed, :from => :received)
    new_event
  end
end

class EventBeingFiredTest < ActiveModel::TestCase
  test 'should raise an AASM::InvalidTransition error if the transitions are empty' do
    event = ActiveModel::StateMachine::Event.new(nil, :event)

    assert_raise ActiveModel::StateMachine::InvalidTransition do
      event.fire(nil)
    end
  end

  test 'should return the state of the first matching transition it finds' do
    event = ActiveModel::StateMachine::Event.new(nil, :event) do
      transitions :to => :closed, :from => [:open, :received]
    end

    obj = stub
    obj.stubs(:current_state).returns(:open)

    assert_equal :closed, event.fire(obj)
  end
end
