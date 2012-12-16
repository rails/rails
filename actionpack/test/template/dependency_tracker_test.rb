require 'abstract_unit'
require 'action_view/dependency_tracker'

class DependencyTrackerTest < ActionView::TestCase
  Neckbeard = Class.new

  class NeckbeardTracker
    def self.call(name, template)
      ["foo/#{name}"]
    end
  end

  class FakeTemplate
    attr_reader :source, :handler

    def initialize(source)
      @source, @handler = source, Neckbeard
    end
  end

  def tracker
    ActionView::DependencyTracker
  end

  def setup
    tracker.register_tracker(Neckbeard, NeckbeardTracker)
  end

  def teardown
    tracker.remove_tracker(Neckbeard)
  end

  def test_finds_tracker_by_template_handler
    template = FakeTemplate.new("boo/hoo")
    dependencies = tracker.find_dependencies("boo/hoo", template)
    assert_equal ["foo/boo/hoo"], dependencies
  end
end
