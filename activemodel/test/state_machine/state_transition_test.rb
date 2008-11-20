require 'test_helper'

class StateTransitionTest < ActiveModel::TestCase
  test 'should set from, to, and opts attr readers' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = ActiveModel::StateMachine::StateTransition.new(opts)

    assert_equal opts[:from], st.from
    assert_equal opts[:to],   st.to
    assert_equal opts,        st.options
  end

  test 'should pass equality check if from and to are the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = ActiveModel::StateMachine::StateTransition.new(opts)

    obj = stub
    obj.stubs(:from).returns(opts[:from])
    obj.stubs(:to).returns(opts[:to])

    assert_equal st, obj
  end

  test 'should fail equality check if from are not the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = ActiveModel::StateMachine::StateTransition.new(opts)

    obj = stub
    obj.stubs(:from).returns('blah')
    obj.stubs(:to).returns(opts[:to])

    assert_not_equal st, obj
  end

  test 'should fail equality check if to are not the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = ActiveModel::StateMachine::StateTransition.new(opts)

    obj = stub
    obj.stubs(:from).returns(opts[:from])
    obj.stubs(:to).returns('blah')

    assert_not_equal st, obj
  end
end

class StateTransitionGuardCheckTest < ActiveModel::TestCase
  test 'should return true of there is no guard' do
    opts = {:from => 'foo', :to => 'bar'}
      st = ActiveModel::StateMachine::StateTransition.new(opts)

    assert st.perform(nil)
  end

  test 'should call the method on the object if guard is a symbol' do
    opts = {:from => 'foo', :to => 'bar', :guard => :test_guard}
    st = ActiveModel::StateMachine::StateTransition.new(opts)
  
    obj = stub
    obj.expects(:test_guard)
    
    st.perform(obj)
  end
  
  test 'should call the method on the object if guard is a string' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'test_guard'}
    st = ActiveModel::StateMachine::StateTransition.new(opts)
  
    obj = stub
    obj.expects(:test_guard)
    
    st.perform(obj)
  end
  
  test 'should call the proc passing the object if the guard is a proc' do
    opts = {:from => 'foo', :to => 'bar', :guard => Proc.new {|o| o.test_guard}}
    st = ActiveModel::StateMachine::StateTransition.new(opts)
  
    obj = stub
    obj.expects(:test_guard)
  
    st.perform(obj)
  end
end
