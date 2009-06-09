require 'test/unit'
$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_support'

class GrandParent
  include ActiveSupport::NewCallbacks
  
  attr_reader :log, :action_name
  def initialize(action_name)
    @action_name, @log = action_name, []
  end
  
  define_callbacks :dispatch
  set_callback :dispatch, :before, :before1, :before2, :per_key => {:if => proc {|c| c.action_name == "index" || c.action_name == "update" }}
  set_callback :dispatch, :after, :after1, :after2, :per_key => {:if => proc {|c| c.action_name == "update" || c.action_name == "delete" }}  
  
  def before1
    @log << "before1"
  end
  
  def before2
    @log << "before2"
  end
  
  def after1 
    @log << "after1"
  end
  
  def after2
    @log << "after2"
  end
  
  def dispatch
    _run_dispatch_callbacks(action_name) do
      @log << action_name
    end
    self
  end
end

class Parent < GrandParent
  skip_callback :dispatch, :before, :before2, :per_key => {:unless => proc {|c| c.action_name == "update" }}
  skip_callback :dispatch, :after, :after2, :per_key => {:unless => proc {|c| c.action_name == "delete" }}
end

class Child < GrandParent
  skip_callback :dispatch, :before, :before2, :per_key => {:unless => proc {|c| c.action_name == "update" }}, :if => :state_open?
  
  def state_open?
    @state == :open
  end
  
  def initialize(action_name, state)
    super(action_name)
    @state = state
  end
end


class BasicCallbacksTest < Test::Unit::TestCase
  def setup
    @index    = GrandParent.new("index").dispatch
    @update   = GrandParent.new("update").dispatch
    @delete   = GrandParent.new("delete").dispatch
    @unknown  = GrandParent.new("unknown").dispatch
  end
  
  def test_basic_per_key1
    assert_equal %w(before1 before2 index), @index.log
  end
  
  def test_basic_per_key2
    assert_equal %w(before1 before2 update after2 after1), @update.log
  end
  
  def test_basic_per_key3
    assert_equal %w(delete after2 after1), @delete.log
  end
end

class InheritedCallbacksTest < Test::Unit::TestCase
  def setup
    @index    = Parent.new("index").dispatch
    @update   = Parent.new("update").dispatch
    @delete   = Parent.new("delete").dispatch
    @unknown  = Parent.new("unknown").dispatch
  end
  
  def test_inherited_excluded
    assert_equal %w(before1 index), @index.log
  end
  
  def test_inherited_not_excluded
    assert_equal %w(before1 before2 update after1), @update.log
  end
  
  def test_partially_excluded
    assert_equal %w(delete after2 after1), @delete.log
  end
end

class InheritedCallbacksTest2 < Test::Unit::TestCase
  def setup
    @update1 = Child.new("update", :open).dispatch
    @update2 = Child.new("update", :closed).dispatch
  end
  
  def test_crazy_mix_on
    assert_equal %w(before1 update after2 after1), @update1.log
  end
  
  def test_crazy_mix_off
    assert_equal %w(before1 before2 update after2 after1), @update2.log
  end
end