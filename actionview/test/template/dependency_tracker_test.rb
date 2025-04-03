# frozen_string_literal: true

require "abstract_unit"
require "action_view/dependency_tracker"

require "action_view/render_parser/prism_render_parser"

require "ripper"
require "action_view/render_parser/ripper_render_parser"

class NeckbeardTracker
  def self.call(name, template)
    ["foo/#{name}"]
  end
end

class FakeTemplate
  attr_reader :source, :handler

  def initialize(source, handler = Neckbeard)
    @source, @handler = source, handler
    if handler == :erb
      @handler = ActionView::Template::Handlers::ERB.new
    end
  end

  def type
    ["text/html"]
  end
end

Neckbeard = lambda { |template, source| source }
Bowtie = lambda { |template, source| source }

class DependencyTrackerTest < ActionView::TestCase
  def tracker
    ActionView::DependencyTracker
  end

  def setup
    ActionView::Template.register_template_handler :neckbeard, Neckbeard
    tracker.register_tracker(:neckbeard, NeckbeardTracker)
  end

  def teardown
    ActionView::Template.unregister_template_handler :neckbeard
    tracker.remove_tracker(:neckbeard)
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

# Tests run with both ERBTracker and RubyTracker
module SharedTrackerTests
  def test_dependency_of_erb_template_with_number_in_filename
    template = FakeTemplate.new("<%= render 'messages/message123' %>", :erb)
    tracker = make_tracker("messages/_message123", template)

    assert_equal ["messages/message123"], tracker.dependencies
  end

  def test_dependency_of_template_partial_with_layout
    template = FakeTemplate.new("<%= render partial: 'messages/show', layout: 'messages/layout' %>", :erb)
    tracker = make_tracker("multiple/_dependencies", template)

    assert_equal ["messages/layout", "messages/show"], tracker.dependencies.sort
  end

  def test_dependency_of_template_layout_standalone
    template = FakeTemplate.new("<%= render layout: 'messages/layout' do %>", :erb)
    tracker = make_tracker("messages/layout", template)

    assert_equal ["messages/layout"], tracker.dependencies
  end

  def test_finds_dependency_in_correct_directory
    template = FakeTemplate.new("<%= render(message.topic) %>", :erb)
    tracker = make_tracker("messages/_message", template)

    assert_equal ["topics/topic"], tracker.dependencies
  end

  def test_finds_dependency_in_correct_directory_with_underscore
    template = FakeTemplate.new("<%= render(message_type.messages) %>", :erb)
    tracker = make_tracker("message_types/_message_type", template)

    assert_equal ["messages/message"], tracker.dependencies
  end

  def test_dependency_of_erb_template_with_no_spaces_after_render
    template = FakeTemplate.new("<%= render'messages/message' %>", :erb)
    tracker = make_tracker("messages/_message", template)

    assert_equal ["messages/message"], tracker.dependencies
  end

  def test_finds_no_dependency_when_render_begins_the_name_of_an_identifier
    template = FakeTemplate.new("<%= rendering 'it useless' %>", :erb)
    tracker = make_tracker("resources/_resource", template)

    assert_equal [], tracker.dependencies
  end

  def test_finds_no_dependency_when_render_ends_the_name_of_another_method
    template = FakeTemplate.new("<%= surrender 'to reason' %>", :erb)
    tracker = make_tracker("resources/_resource", template)

    assert_equal [], tracker.dependencies
  end

  def test_finds_dependency_on_multiline_render_calls
    template = FakeTemplate.new("<%=
      render object: @all_posts,
             partial: 'posts' %>", :erb)

    tracker = make_tracker("some/_little_posts", template)

    assert_equal ["some/posts"], tracker.dependencies
  end

  def test_finds_multiple_unrelated_odd_dependencies
    template = FakeTemplate.new("
      <%= render('application/header', title: 'Title') %>
      <h2>Section title</h2>
      <%= render@section %>
    ", :erb)

    tracker = make_tracker("multiple/_dependencies", template)

    assert_equal ["application/header", "sections/section"], tracker.dependencies
  end

  def test_finds_dependencies_for_all_kinds_of_identifiers
    template = FakeTemplate.new("
      <%= render $globals %>
      <%= render @instance_variables %>
      <%= render @@class_variables %>
    ", :erb)

    tracker = make_tracker("identifiers/_all", template)

    assert_equal [
      "globals/global",
      "instance_variables/instance_variable",
      "class_variables/class_variable"
    ], tracker.dependencies
  end

  def test_finds_dependencies_on_method_chains
    template = FakeTemplate.new("<%= render @parent.child.grandchildren %>", :erb)
    tracker = make_tracker("method/_chains", template)

    assert_equal ["grandchildren/grandchild"], tracker.dependencies
  end

  def test_finds_dependencies_with_special_characters
    template = FakeTemplate.new("<%= render partial: 'ピカチュウ', object: @pokémon %>", :erb)
    tracker = make_tracker("special/_characters", template)

    assert_equal ["special/ピカチュウ"], tracker.dependencies
  end

  def test_finds_dependencies_with_quotes_within
    template = FakeTemplate.new(%{
      <%= render "single/quote's" %>
      <%= render 'double/quote"s' %>
    }, :erb)

    tracker = make_tracker("quotes/_single_and_double", template)

    assert_equal ["single/quote's", 'double/quote"s'], tracker.dependencies
  end

  def test_finds_dependencies_with_extra_spaces
    template = FakeTemplate.new(%{
      <%= render              "header" %>
      <%= render    partial:  "form" %>
      <%= render              @message %>
      <%= render ( @message.events ) %>
      <%= render    :collection => @message.comments,
                    :partial =>    "comments/comment" %>
    }, :erb)

    tracker = make_tracker("spaces/_extra", template)

    assert_equal [
      "spaces/header",
      "spaces/form",
      "messages/message",
      "events/event",
      "comments/comment"
    ], tracker.dependencies
  end

  def test_finds_dependencies_with_bare_assoc_hash_on_constant
    template = FakeTemplate.new(%{
      <%= render SomeConstant.message(this: "that") %>
    }, :erb)

    tracker = make_tracker("assoc_hash/const", template)

    assert_equal [
      "messages/message",
    ], tracker.dependencies
  end

  def test_dependencies_with_interpolation
    template = FakeTemplate.new(%q{
      <%= render "double/#{quote}" %>
      <%= render 'single/#{quote}' %>
    }, :erb)
    tracker = make_tracker("interpolation/_string", template)

    assert_equal ["single/\#{quote}"], tracker.dependencies
  end

  def test_dependencies_with_interpolation_are_resolved_with_view_paths
    view_paths = ActionView::PathSet.new([File.expand_path("../fixtures/digestor", __dir__)])

    template = FakeTemplate.new(%q{
      <%= render "events/#{quote}" %>
    }, :erb)

    tracker = make_tracker("interpolation/_string", template, view_paths)

    assert_equal ["events/_completed", "events/_event", "events/index"], tracker.dependencies
  end

  def test_dependencies_with_interpolation_non_trailing
    view_paths = ActionView::PathSet.new([File.expand_path("../fixtures/digestor", __dir__)])

    template = FakeTemplate.new(%q{
      <%= render "#{type}/comments" %>
    }, :erb)

    tracker = make_tracker("interpolation/_string", template, view_paths)

    assert_equal [ "*/comments" ], tracker.dependencies
  end

  def test_dependencies_with_interpolation_expr
    view_paths = ActionView::PathSet.new([File.expand_path("../fixtures/digestor", __dir__)])

    template = FakeTemplate.new(%q{
      <%= render "orders/#{variable || "default"}" %>
    }, :erb)

    tracker = make_tracker("interpolation/_string", template, view_paths)

    # unsupported
    assert_equal [], tracker.dependencies
  end
end

class ERBTrackerTest < ActiveSupport::TestCase
  include SharedTrackerTests

  def make_tracker(name, template, view_paths = nil)
    ActionView::DependencyTracker::ERBTracker.new(name, template, view_paths)
  end
end

module RubyTrackerTests
  def make_tracker(name, template, view_paths = nil)
    ActionView::DependencyTracker::RubyTracker.new(name, template, view_paths, parser_class: parser_class)
  end

  def test_dependencies_skip_unknown_options
    template = FakeTemplate.new(%{
      <%= render partial: "unknown_render_call", unknown_render_option: "yes" %>
    }, :erb)
    tracker = make_tracker("interpolation/_string", template)

    assert_equal [], tracker.dependencies
  end

  def test_dependencies_finds_spacer_templates
    template = FakeTemplate.new(%{
      <%= render partial: "messages/message", collection: books, spacer_template: "messages/message_spacer" %>
    }, :erb)
    tracker = make_tracker("messages/show", template)

    assert_equal ["messages/message_spacer", "messages/message"], tracker.dependencies
  end

  def test_dependencies_skip_commented_out_renders
    template = FakeTemplate.new(%{
      <%# render "messages/legacy_message" %>
    }, :erb)
    tracker = make_tracker("messages/show", template)

    assert_equal [], tracker.dependencies
  end
end

class RipperRubyTrackerTest < ActiveSupport::TestCase
  include SharedTrackerTests
  include RubyTrackerTests

  def parser_class
    ActionView::RenderParser::RipperRenderParser
  end
end

class PrismRubyTrackerTest < ActiveSupport::TestCase
  include SharedTrackerTests
  include RubyTrackerTests

  def parser_class
    ActionView::RenderParser::PrismRenderParser
  end
end
