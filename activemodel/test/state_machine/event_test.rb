require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class EventTest < ActiveModel::TestCase
  def setup
    @name = :close_order
    @success = :success_callback
  end

  def new_event
    @event = ActiveModel::StateMachine::Event.new(nil, @name, {:success => @success}) do
      transitions :to => :closed, :from => [:open, :received]
    end
  end

  test 'should set the name' do
    assert_equal @name, new_event.name
  end

  test 'should set the success option' do
    assert_equal @success, new_event.success
  end

  uses_mocha 'StateTransition creation' do
    test 'should create StateTransitions' do
      ActiveModel::StateMachine::StateTransition.expects(:new).with(:to => :closed, :from => :open)
      ActiveModel::StateMachine::StateTransition.expects(:new).with(:to => :closed, :from => :received)
      new_event
    end
  end
end

class EventBeingFiredTest < ActiveModel::TestCase
  test 'should raise an AASM::InvalidTransition error if the transitions are empty' do
    event = ActiveModel::StateMachine::Event.new(nil, :event)

    assert_raises ActiveModel::StateMachine::InvalidTransition do
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
