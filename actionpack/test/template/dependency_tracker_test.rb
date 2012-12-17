require 'abstract_unit'
require 'action_view/dependency_tracker'

class DependencyTrackerTest < ActionView::TestCase
  Neckbeard = Class.new
  Bowtie = Class.new

  class NeckbeardTracker
    def self.call(name, template)
      ["foo/#{name}"]
    end
  end

  class FakeTemplate
    attr_reader :source, :handler

    def initialize(source, handler = Neckbeard)
      @source, @handler = source, handler
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

  def test_returns_empty_array_if_no_tracker_is_found
    template = FakeTemplate.new("boo/hoo", Bowtie)
    dependencies = tracker.find_dependencies("boo/hoo", template)
    assert_equal [], dependencies
  end
end
