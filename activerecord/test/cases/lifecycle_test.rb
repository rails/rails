require "cases/helper"
require 'models/topic'
require 'models/developer'
require 'models/reply'
require 'models/minimalistic'

class Topic; def after_find() end end
class Developer; def after_find() end end
class SpecialDeveloper < Developer; end

class TopicManualObserver
  include Singleton

  attr_reader :action, :object, :callbacks

  def initialize
    Topic.add_observer(self)
    @callbacks = []
  end

  def update(callback_method, object)
    @callbacks << { "callback_method" => callback_method, "object" => object }
  end

  def has_been_notified?
    !@callbacks.empty?
  end
end

class TopicaAuditor < ActiveRecord::Observer
  observe :topic

  attr_reader :topic

  def after_find(topic)
    @topic = topic
  end
end

class TopicObserver < ActiveRecord::Observer
  attr_reader :topic

  def after_find(topic)
    @topic = topic
  end
end

class MinimalisticObserver < ActiveRecord::Observer
  attr_reader :minimalistic

  def after_find(minimalistic)
    @minimalistic = minimalistic
  end
end

class MultiObserver < ActiveRecord::Observer
  attr_reader :record

  def self.observed_class() [ Topic, Developer ] end

  cattr_reader :last_inherited
  @@last_inherited = nil

  def observed_class_inherited_with_testing(subclass)
    observed_class_inherited_without_testing(subclass)
    @@last_inherited = subclass
  end

  alias_method_chain :observed_class_inherited, :testing

  def after_find(record)
    @record = record
  end
end

class LifecycleTest < ActiveRecord::TestCase
  fixtures :topics, :developers, :minimalistics

  def test_before_destroy
    original_count = Topic.count
    (topic_to_be_destroyed = Topic.find(1)).destroy
    assert_equal original_count - (1 + topic_to_be_destroyed.replies.size), Topic.count
  end

  def test_after_save
    ActiveRecord::Base.observers = :topic_manual_observer
    ActiveRecord::Base.instantiate_observers

    topic = Topic.find(1)
    topic.title = "hello"
    topic.save

    assert TopicManualObserver.instance.has_been_notified?
    assert_equal :after_save, TopicManualObserver.instance.callbacks.last["callback_method"]
  end

  def test_observer_update_on_save
    ActiveRecord::Base.observers = TopicManualObserver
    ActiveRecord::Base.instantiate_observers

    topic = Topic.find(1)
    assert TopicManualObserver.instance.has_been_notified?
    assert_equal :after_find, TopicManualObserver.instance.callbacks.first["callback_method"]
  end

  def test_auto_observer
    topic_observer = TopicaAuditor.instance
    assert_nil TopicaAuditor.observed_class
    assert_equal [Topic], TopicaAuditor.instance.observed_classes.to_a

    topic = Topic.find(1)
    assert_equal topic.title, topic_observer.topic.title
  end

  def test_inferred_auto_observer
    topic_observer = TopicObserver.instance
    assert_equal Topic, TopicObserver.observed_class

    topic = Topic.find(1)
    assert_equal topic.title, topic_observer.topic.title
  end

  def test_observing_two_classes
    multi_observer = MultiObserver.instance

    topic = Topic.find(1)
    assert_equal topic.title, multi_observer.record.title

    developer = Developer.find(1)
    assert_equal developer.name, multi_observer.record.name
  end

  def test_observing_subclasses
    multi_observer = MultiObserver.instance

    developer = SpecialDeveloper.find(1)
    assert_equal developer.name, multi_observer.record.name

    klass = Class.new(Developer)
    assert_equal klass, multi_observer.last_inherited

    developer = klass.find(1)
    assert_equal developer.name, multi_observer.record.name
  end

  def test_after_find_can_be_observed_when_its_not_defined_on_the_model
    observer = MinimalisticObserver.instance
    assert_equal Minimalistic, MinimalisticObserver.observed_class

    minimalistic = Minimalistic.find(1)
    assert_equal minimalistic, observer.minimalistic
  end

  def test_after_find_can_be_observed_when_its_defined_on_the_model
    observer = TopicObserver.instance
    assert_equal Topic, TopicObserver.observed_class

    topic = Topic.find(1)
    assert_equal topic, observer.topic
  end

  def test_after_find_is_not_created_if_its_not_used
    # use a fresh class so an observer can't have defined an
    # after_find on it
    model_class = Class.new(ActiveRecord::Base)
    observer_class = Class.new(ActiveRecord::Observer)
    observer_class.observe(model_class)

    observer = observer_class.instance

    assert !model_class.method_defined?(:after_find)
  end

  def test_after_find_is_not_clobbered_if_it_already_exists
    # use a fresh observer class so we can instantiate it (Observer is
    # a Singleton)
    model_class = Class.new(ActiveRecord::Base) do
      def after_find; end
    end
    original_method = model_class.instance_method(:after_find)
    observer_class = Class.new(ActiveRecord::Observer) do
      def after_find; end
    end
    observer_class.observe(model_class)

    observer = observer_class.instance
    assert_equal original_method, model_class.instance_method(:after_find)
  end

  def test_invalid_observer
    assert_raise(ArgumentError) { Topic.observers = Object.new; Topic.instantiate_observers }
  end
end
