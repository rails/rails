require 'cases/helper'

class ObservedModel
  include ActiveModel::Observing

  class Observer
  end
end

class FooObserver < ActiveModel::Observer
  class << self
    public :new
  end

  attr_accessor :stub

  def on_spec(record, *args)
    stub.event_with(record, *args) if stub
  end

  def around_save(record)
    yield :in_around_save
  end
end

class Foo
  include ActiveModel::Observing
end

class ObservingTest < ActiveModel::TestCase
  def setup
    ObservedModel.observers.clear
  end

  test "initializes model with no cached observers" do
    assert ObservedModel.observers.empty?, "Not empty: #{ObservedModel.observers.inspect}"
  end

  test "stores cached observers in an array" do
    ObservedModel.observers << :foo
    assert ObservedModel.observers.include?(:foo), ":foo not in #{ObservedModel.observers.inspect}"
  end

  test "flattens array of assigned cached observers" do
    ObservedModel.observers = [[:foo], :bar]
    assert ObservedModel.observers.include?(:foo), ":foo not in #{ObservedModel.observers.inspect}"
    assert ObservedModel.observers.include?(:bar), ":bar not in #{ObservedModel.observers.inspect}"
  end

  test "uses an ObserverArray so observers can be disabled" do
    ObservedModel.observers = [:foo, :bar]
    assert ObservedModel.observers.is_a?(ActiveModel::ObserverArray)
  end

  test "instantiates observer names passed as strings" do
    ObservedModel.observers << 'foo_observer'
    FooObserver.expects(:instance)
    ObservedModel.instantiate_observers
  end

  test "instantiates observer names passed as symbols" do
    ObservedModel.observers << :foo_observer
    FooObserver.expects(:instance)
    ObservedModel.instantiate_observers
  end

  test "instantiates observer classes" do
    ObservedModel.observers << ObservedModel::Observer
    ObservedModel::Observer.expects(:instance)
    ObservedModel.instantiate_observers
  end

  test "passes observers to subclasses" do
    FooObserver.instance
    bar = Class.new(Foo)
    assert_equal Foo.count_observers, bar.count_observers
  end
end

class ObserverTest < ActiveModel::TestCase
  def setup
    ObservedModel.observers = :foo_observer
    FooObserver.instance_eval do
      alias_method :original_observed_classes, :observed_classes
    end
  end

  def teardown
    FooObserver.instance_eval do
      undef_method :observed_classes
      alias_method :observed_classes, :original_observed_classes
    end
  end

  test "guesses implicit observable model name" do
    assert_equal Foo, FooObserver.observed_class
  end

  test "tracks implicit observable models" do
    instance = FooObserver.new
    assert  instance.send(:observed_classes).include?(Foo), "Foo not in #{instance.send(:observed_classes).inspect}"
    assert !instance.send(:observed_classes).include?(ObservedModel), "ObservedModel in #{instance.send(:observed_classes).inspect}"
  end

  test "tracks explicit observed model class" do
    old_instance = FooObserver.new
    assert !old_instance.send(:observed_classes).include?(ObservedModel), "ObservedModel in #{old_instance.send(:observed_classes).inspect}"
    FooObserver.observe ObservedModel
    instance = FooObserver.new
    assert instance.send(:observed_classes).include?(ObservedModel), "ObservedModel not in #{instance.send(:observed_classes).inspect}"
  end

  test "tracks explicit observed model as string" do
    old_instance = FooObserver.new
    assert !old_instance.send(:observed_classes).include?(ObservedModel), "ObservedModel in #{old_instance.send(:observed_classes).inspect}"
    FooObserver.observe 'observed_model'
    instance = FooObserver.new
    assert instance.send(:observed_classes).include?(ObservedModel), "ObservedModel not in #{instance.send(:observed_classes).inspect}"
  end

  test "tracks explicit observed model as symbol" do
    old_instance = FooObserver.new
    assert !old_instance.send(:observed_classes).include?(ObservedModel), "ObservedModel in #{old_instance.send(:observed_classes).inspect}"
    FooObserver.observe :observed_model
    instance = FooObserver.new
    assert instance.send(:observed_classes).include?(ObservedModel), "ObservedModel not in #{instance.send(:observed_classes).inspect}"
  end

  test "calls existing observer event" do
    foo = Foo.new
    FooObserver.instance.stub = stub
    FooObserver.instance.stub.expects(:event_with).with(foo)
    Foo.send(:notify_observers, :on_spec, foo)
  end

  test "passes extra arguments" do
    foo = Foo.new
    FooObserver.instance.stub = stub
    FooObserver.instance.stub.expects(:event_with).with(foo, :bar)
    Foo.send(:notify_observers, :on_spec, foo, :bar)
  end

  test "skips nonexistent observer event" do
    foo = Foo.new
    Foo.send(:notify_observers, :whatever, foo)
  end

  test "update passes a block on to the observer" do
    yielded_value = nil
    FooObserver.instance.update(:around_save, Foo.new) do |val|
      yielded_value = val
    end
    assert_equal :in_around_save, yielded_value
  end
end
