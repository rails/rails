# frozen_string_literal: true

require "abstract_unit"

class TemplateErrorTest < ActiveSupport::TestCase
  def test_provides_original_message
    error = begin
      raise Exception.new("original")
    rescue Exception
      raise ActionView::Template::Error.new("test") rescue $!
    end

    assert_equal "original", error.message
  end

  def test_provides_original_backtrace
    error = begin
      original_exception = Exception.new
      original_exception.set_backtrace(%W[ foo bar baz ])
      raise original_exception
    rescue Exception
      raise ActionView::Template::Error.new("test") rescue $!
    end

    assert_equal %W[ foo bar baz ], error.backtrace
  end

  def test_provides_useful_inspect
    error = begin
      raise Exception.new("original")
    rescue Exception
      raise ActionView::Template::Error.new("test") rescue $!
    end

    assert_equal "#<ActionView::Template::Error: original>", error.inspect
  end

  def test_annotated_source_code_returns_empty_array_if_source_cant_be_found
    template = Class.new do
      def identifier
        "something"
      end
    end.new

    error = begin
      raise
    rescue
      raise ActionView::Template::Error.new(template) rescue $!
    end

    assert_equal [], error.annotated_source_code
  end

  def test_templates_lists_the_rendering_templates_from_the_innermost
    view_paths = ActionView::PathSet.new([ActionView::FixtureResolver.new(
      "tests/show.html.erb" => "<%= render 'tests/list' %>",
      "tests/_list.html.erb" => "<%= render 'tests/item' %>",
      "tests/_item.html.erb" => "<%= raise 'boom' %>"
    )])
    view = ActionView::Base.with_empty_template_cache.with_view_paths(view_paths)

    error = assert_raises(ActionView::Template::Error) do
      view.render(template: "tests/show")
    end

    assert_equal ["tests/_item", "tests/_list", "tests/show"], error.templates.map(&:virtual_path)
  end
end
