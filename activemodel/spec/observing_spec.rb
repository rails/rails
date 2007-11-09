require File.join(File.dirname(__FILE__), 'spec_helper')

class ObservedModel < ActiveModel::Base
  class Observer
  end
end

class FooObserver < ActiveModel::Observer
  class << self
    public :new
  end
  
  attr_accessor :stub

  def on_spec(record)
    stub.event_with(record) if stub
  end
end

class Foo < ActiveModel::Base
end

module ActiveModel
  describe Observing do
    before do
      ObservedModel.observers.clear
    end

    it "initializes model with no cached observers" do
      ObservedModel.observers.should be_empty
    end
    
    it "stores cached observers in an array" do
      ObservedModel.observers << :foo
      ObservedModel.observers.should include(:foo)
    end
    
    it "flattens array of assigned cached observers" do
      ObservedModel.observers = [[:foo], :bar]
      ObservedModel.observers.should include(:foo)
      ObservedModel.observers.should include(:bar)
    end
    
    it "instantiates observer names passed as strings" do
      ObservedModel.observers << 'foo_observer'
      FooObserver.should_receive(:instance)
      ObservedModel.instantiate_observers
    end
    
    it "instantiates observer names passed as symbols" do
      ObservedModel.observers << :foo_observer
      FooObserver.should_receive(:instance)
      ObservedModel.instantiate_observers
    end
    
    it "instantiates observer classes" do
      ObservedModel.observers << ObservedModel::Observer
      ObservedModel::Observer.should_receive(:instance)
      ObservedModel.instantiate_observers
    end
    
    it "should pass observers to subclasses" do
      FooObserver.instance
      bar = Class.new(Foo)
      bar.count_observers.should == 1
    end
  end
  
  describe Observer do
    before do
      ObservedModel.observers = :foo_observer
      FooObserver.models = nil
    end

    it "guesses implicit observable model name" do
      FooObserver.observed_class_name.should == 'Foo'
    end

    it "tracks implicit observable models" do
      instance = FooObserver.new
      instance.send(:observed_classes).should     include(Foo)
      instance.send(:observed_classes).should_not include(ObservedModel)
    end
    
    it "tracks explicit observed model class" do
      FooObserver.new.send(:observed_classes).should_not include(ObservedModel)
      FooObserver.observe ObservedModel
      instance = FooObserver.new
      instance.send(:observed_classes).should include(ObservedModel)
    end
    
    it "tracks explicit observed model as string" do
      FooObserver.new.send(:observed_classes).should_not include(ObservedModel)
      FooObserver.observe 'observed_model'
      instance = FooObserver.new
      instance.send(:observed_classes).should include(ObservedModel)
    end
    
    it "tracks explicit observed model as symbol" do
      FooObserver.new.send(:observed_classes).should_not include(ObservedModel)
      FooObserver.observe :observed_model
      instance = FooObserver.new
      instance.send(:observed_classes).should include(ObservedModel)
    end
    
    it "calls existing observer event" do
      foo = Foo.new
      FooObserver.instance.stub = stub!(:stub)
      FooObserver.instance.stub.should_receive(:event_with).with(foo)
      Foo.send(:changed)
      Foo.send(:notify_observers, :on_spec, foo)
    end
    
    it "skips nonexistent observer event" do
      foo = Foo.new
      Foo.send(:changed)
      Foo.send(:notify_observers, :whatever, foo)
    end
  end
end