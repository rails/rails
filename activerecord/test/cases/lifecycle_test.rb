require 'cases/helper'
require 'models/topic'
require 'models/developer'
require 'models/reply'
require 'models/minimalistic'
require 'models/comment'

class SpecialDeveloper < Developer; end

class DeveloperObserver < ActiveRecord::Observer
  def calls
    @calls ||= []
  end

  def before_save(developer)
    calls << developer
  end
end

class SalaryChecker < ActiveRecord::Observer
  observe :special_developer
  attr_accessor :last_saved

  def before_save(developer)
    return developer.salary > 80000
  end

  module Implementation
    def after_save(developer)
      self.last_saved = developer
    end
  end
  include Implementation

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

  # Create an after_save callback, so a notify_observer hook is created
  # on :topic.
  def after_save(nothing)
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

class ValidatedComment < Comment
  attr_accessor :callers

  before_validation :record_callers

  after_validation do
    record_callers
  end

  def record_callers
    callers << self.class if callers
  end
end

class ValidatedCommentObserver < ActiveRecord::Observer
  attr_accessor :callers

  def after_validation(model)
    callers << self.class if callers
  end
end


class AroundTopic < Topic
end

class AroundTopicObserver < ActiveRecord::Observer
  observe :around_topic
  def topic_ids
    @topic_ids ||= []
  end

  def around_save(topic)
    topic_ids << topic.id
    yield(topic)
    topic_ids << topic.id
  end
end

class LifecycleTest < ActiveRecord::TestCase
  fixtures :topics, :developers, :minimalistics

  def test_before_destroy
    topic = Topic.find(1)
    assert_difference 'Topic.count', -(1 + topic.replies.size) do
      topic.destroy
    end
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

  def test_invalid_observer
    assert_raise(ArgumentError) { Topic.observers = Object.new; Topic.instantiate_observers }
  end

  test "model callbacks fire before observers are notified" do
    callers = []

    comment = ValidatedComment.new
    comment.callers = ValidatedCommentObserver.instance.callers = callers

    comment.valid?
    assert_equal [ValidatedComment, ValidatedComment, ValidatedCommentObserver], callers,
      "model callbacks did not fire before observers were notified"
  end

  test "able to save developer" do
    SalaryChecker.instance # activate
    developer = SpecialDeveloper.new :name => 'Roger', :salary => 100000
    assert developer.save, "developer with normal salary failed to save"
  end

  test "unable to save developer with low salary" do
    SalaryChecker.instance # activate
    developer = SpecialDeveloper.new :name => 'Rookie', :salary => 50000
    assert !developer.save, "allowed to save a developer with too low salary"
  end

  test "able to call methods defined with included module" do # https://rails.lighthouseapp.com/projects/8994/tickets/6065-activerecordobserver-is-not-aware-of-method-added-by-including-modules
    SalaryChecker.instance # activate
    developer = SpecialDeveloper.create! :name => 'Roger', :salary => 100000
    assert_equal developer, SalaryChecker.instance.last_saved
  end

  test "around filter from observer should accept block" do
    observer = AroundTopicObserver.instance
    topic = AroundTopic.new
    topic.save
    assert_nil observer.topic_ids.first
    assert_not_nil observer.topic_ids.last
  end

  test "able to disable observers" do
    observer = DeveloperObserver.instance # activate
    observer.calls.clear

    ActiveRecord::Base.observers.disable DeveloperObserver do
      Developer.create! :name => 'Ancestor', :salary => 100000
      SpecialDeveloper.create! :name => 'Descendent', :salary => 100000
    end

    assert_equal [], observer.calls
  end

  def test_observer_is_called_once
    observer = DeveloperObserver.instance # activate
    observer.calls.clear

    developer = Developer.create! :name => 'Ancestor', :salary => 100000
    special_developer = SpecialDeveloper.create! :name => 'Descendent', :salary => 100000

    assert_equal [developer, special_developer], observer.calls
  end

end
