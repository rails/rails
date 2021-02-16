# frozen_string_literal: true

require "abstract_unit"

class CompiledTemplatesTest < ActiveSupport::TestCase
  attr_reader :view_class

  def setup
    super
    view_paths = ActionController::Base.view_paths
    view_paths.each(&:clear_cache)
    ActionView::LookupContext.fallbacks.each(&:clear_cache)
    @view_class = ActionView::Base.with_empty_template_cache
  end

  def teardown
    super
    ActionView::LookupContext::DetailsKey.clear
  end

  def test_template_with_nil_erb_return
    assert_equal "This is nil: \n", render(template: "test/nil_return")
  end

  def test_template_with_ruby_keyword_locals
    assert_equal "The class is foo",
      render(template: "test/render_file_with_ruby_keyword_locals", locals: { class: "foo" })
  end

  def test_template_with_invalid_identifier_locals
    locals = {
      foo: "bar",
      Foo: "bar",
      "d-a-s-h-e-s": "",
      "white space": "",
    }
    assert_equal locals.inspect, render(template: "test/render_file_inspect_local_assigns", locals: locals)
  end

  def test_template_with_delegation_reserved_keywords
    locals = {
      _: "one",
      arg: "two",
      args: "three",
      block: "four",
    }
    assert_equal "one two three four", render(template: "test/test_template_with_delegation_reserved_keywords", locals: locals)
  end

  def test_template_with_unicode_identifier
    assert_equal "🎂", render(template: "test/render_file_unicode_local", locals: { 🎃: "🎂" })
  end

  def test_template_with_instance_variable_identifier
    expected_deprecation = "In Rails 7.0, @foo will be ignored."
    assert_deprecated(expected_deprecation) do
      assert_equal "bar", render(template: "test/render_file_instance_variable", locals: { "@foo": "bar" })
    end
  end

  def test_template_gets_recompiled_when_using_different_keys_in_local_assigns
    assert_equal "one", render(template: "test/render_file_with_locals_and_default")
    assert_equal "two", render(template: "test/render_file_with_locals_and_default", locals: { secret: "two" })
  end

  private
    def render(*args)
      ActionController::Base.render(*args)
    end
end
