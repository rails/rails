require "abstract_unit"

class GrandParent
  include ActiveSupport::Callbacks

  attr_reader :log, :action_name
  def initialize(action_name)
    @action_name, @log = action_name, []
  end

  define_callbacks :dispatch
  set_callback :dispatch, :before, :before1, :before2, :if => proc {|c| c.action_name == "index" || c.action_name == "update" }
  set_callback :dispatch, :after, :after1, :after2, :if => proc {|c| c.action_name == "update" || c.action_name == "delete" }

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
    run_callbacks :dispatch do
      @log << action_name
    end
    self
  end
end

class Parent < GrandParent
  skip_callback :dispatch, :before, :before2, :unless => proc {|c| c.action_name == "update" }
  skip_callback :dispatch, :after, :after2, :unless => proc {|c| c.action_name == "delete" }
end

class Child < GrandParent
  skip_callback :dispatch, :before, :before2, :unless => proc {|c| c.action_name == "update" }, :if => :state_open?

  def state_open?
    @state == :open
  end

  def initialize(action_name, state)
    super(action_name)
    @state = state
  end
end

class EmptyParent
  include ActiveSupport::Callbacks

  def performed?
    @performed ||= false
  end

  define_callbacks :dispatch

  def perform!
    @performed = true
  end

  def dispatch
    run_callbacks :dispatch
    self
  end
end

class EmptyChild < EmptyParent
  set_callback :dispatch, :before, :do_nothing

  def do_nothing
  end
end

class CountingParent
  include ActiveSupport::Callbacks

  attr_reader :count

  define_callbacks :dispatch

  def initialize
    @count = 0
  end

  def count!
    @count += 1
  end

  def dispatch
    run_callbacks(:dispatch)
    self
  end
end

class CountingChild < CountingParent
end

class BasicCallbacksTest < ActiveSupport::TestCase
  def setup
    @index    = GrandParent.new("index").dispatch
    @update   = GrandParent.new("update").dispatch
    @delete   = GrandParent.new("delete").dispatch
  end

  def test_basic_conditional_callback1
    assert_equal %w(before1 before2 index), @index.log
  end

  def test_basic_conditional_callback2
    assert_equal %w(before1 before2 update after2 after1), @update.log
  end

  def test_basic_conditional_callback3
    assert_equal %w(delete after2 after1), @delete.log
  end
end

class InheritedCallbacksTest < ActiveSupport::TestCase
  def setup
    @index    = Parent.new("index").dispatch
    @update   = Parent.new("update").dispatch
    @delete   = Parent.new("delete").dispatch
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

class InheritedCallbacksTest2 < ActiveSupport::TestCase
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

class DynamicInheritedCallbacks < ActiveSupport::TestCase
  def test_callbacks_looks_to_the_superclass_before_running
    child = EmptyChild.new.dispatch
    assert !child.performed?
    EmptyParent.set_callback :dispatch, :before, :perform!
    child = EmptyChild.new.dispatch
    assert child.performed?
  end

  def test_callbacks_should_be_performed_once_in_child_class
    CountingParent.set_callback(:dispatch, :before) { count! }
    child = CountingChild.new.dispatch
    assert_equal 1, child.count
  end
end
