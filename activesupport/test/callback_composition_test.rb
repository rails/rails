# frozen_string_literal: true

require_relative "abstract_unit"

module CallbackCompositionTestFixtures
  class GreatAncientOne
    include ActiveSupport::Callbacks

    attr_reader :log, :action_name
    def initialize(action_name)
      @action_name, @log = action_name, []
    end

    define_callbacks :dispatch

    def dispatch
      run_callbacks :dispatch do
        @log << action_name
      end
      self
    end
  end

  module IndexLogging
    def self.included(base)
      base.set_callback :dispatch, :before, :log_action, if: proc { |c| c.action_name == "index" }
    end

    def log_action
      @log << "IndexLogging"
    end
  end

  module ShowLogging
    def self.included(base)
      base.set_callback :dispatch, :before, :log_action, if: proc { |c| c.action_name == "show" }
    end

    def log_action
      @log << "ShowLogging"
    end
  end
end

class BasicCallbacksTest < ActiveSupport::TestCase
  include CallbackCompositionTestFixtures

  class Parent < GreatAncientOne; end

  def setup
    @index = Parent.new("index").dispatch
  end

  def test_logging_works
    assert_equal ["index"], @index.log
  end
end

class ParentIncludesWithoutChildTest < ActiveSupport::TestCase
  include CallbackCompositionTestFixtures

  class Parent < GreatAncientOne; end

  def setup
    Parent.include(IndexLogging)
    @index = Parent.new("index").dispatch
  end

  def test_logging
    assert_equal %w(IndexLogging index), @index.log
  end
end

class ParentIncludesCallbackAfterChildTest < ActiveSupport::TestCase
  include CallbackCompositionTestFixtures

  class Parent < GreatAncientOne; end
  class Child < Parent
    include CallbackCompositionTestFixtures::ShowLogging
  end

  def setup
    Parent.include(IndexLogging)

    @parent_index = Parent.new("index").dispatch
    @parent_show = Parent.new("show").dispatch
    @child_index = Child.new("index").dispatch
    @child_show = Child.new("show").dispatch
  end

  def test_basic_parent_logging_works
    assert_equal %w(IndexLogging index), @parent_index.log
    assert_equal %w(show), @parent_show.log
  end

  def test_child_index_includes_show_logging
    assert_equal %w(ShowLogging index), @child_index.log
  end

  def test_child_show_action_not_overrode_by_parent_include
    assert_equal %w(ShowLogging show), @child_show.log
  end
end

class ParentIncludesCallbackAfterChildWithSkippingAllTest < ActiveSupport::TestCase
  include CallbackCompositionTestFixtures

  class Parent < GreatAncientOne; end
  class Child < Parent
    include CallbackCompositionTestFixtures::ShowLogging

    skip_callback :dispatch, :log_action
  end

  def setup
    Parent.include(IndexLogging)

    @child_index = Child.new("index").dispatch
  end

  def test_skip_callback_called_before_include_misses_removal_of_callback_from_parent
    # ShowLogging because it is calling log_action included from IndexLogging
    # but the included method from ShowLogging
    assert_equal %w(ShowLogging index), @child_index.log
  end
end

class SkipRemovesAllCallbacksWhenCalledAfterIncludes < ActiveSupport::TestCase
  include CallbackCompositionTestFixtures

  class Parent < GreatAncientOne
    include CallbackCompositionTestFixtures::IndexLogging
  end
  class Child < Parent
    include CallbackCompositionTestFixtures::ShowLogging

    skip_callback :dispatch, :log_action
  end

  def setup
    @child_index = Child.new("index").dispatch
  end

  def test_child_skip_callbacks_removes_all_log_action_callbacks
    assert_equal %w(index), @child_index.log
  end
end
