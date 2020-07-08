# coding: utf-8
require 'abstract_unit'

class CompiledTemplatesTest < ActiveSupport::TestCase
  teardown do
    ActionView::LookupContext::DetailsKey.clear
  end

  def test_template_with_nil_erb_return
    assert_equal "This is nil: \n", render(:template => "test/nil_return")
  end

  def test_template_with_ruby_keyword_locals
    assert_equal "The class is foo",
                 render(file: "test/render_file_with_ruby_keyword_locals", locals: { class: "foo" })
  end

  def test_template_with_invalid_identifier_locals
    locals = {
      foo: "bar",
      Foo: "bar",
      :"d-a-s-h-e-s" => "",
      :"white space" => "",
    }
    assert_equal locals.inspect, render(file: "test/render_file_inspect_local_assigns", locals: locals)
  end

  def test_template_with_delegation_reserved_keywords
    locals = {
      _: "one",
      arg: "two",
      args: "three",
      block: "four",
    }
    assert_equal "one two three four", render(file: "test/test_template_with_delegation_reserved_keywords", locals: locals)
  end

  def test_template_with_unicode_identifier
    assert_equal "🎂", render(file: "test/render_file_unicode_local", locals: { 🎃: "🎂" })
  end

  def test_template_gets_recompiled_when_using_different_keys_in_local_assigns
    assert_equal "one", render(:file => "test/render_file_with_locals_and_default")
    assert_equal "two", render(:file => "test/render_file_with_locals_and_default", :locals => { :secret => "two" })
  end

  def test_template_changes_are_not_reflected_with_cached_templates
    assert_equal "Hello world!", render(:file => "test/hello_world")
    modify_template "test/hello_world.erb", "Goodbye world!" do
      assert_equal "Hello world!", render(:file => "test/hello_world")
    end
    assert_equal "Hello world!", render(:file => "test/hello_world")
  end

  def test_template_changes_are_reflected_with_uncached_templates
    assert_equal "Hello world!", render_without_cache(:file => "test/hello_world")
    modify_template "test/hello_world.erb", "Goodbye world!" do
      assert_equal "Goodbye world!", render_without_cache(:file => "test/hello_world")
    end
    assert_equal "Hello world!", render_without_cache(:file => "test/hello_world")
  end

  private
    def render(*args)
      render_with_cache(*args)
    end

    def render_with_cache(*args)
      view_paths = ActionController::Base.view_paths
      ActionView::Base.new(view_paths, {}).render(*args)
    end

    def render_without_cache(*args)
      path = ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH)
      view_paths = ActionView::PathSet.new([path])
      ActionView::Base.new(view_paths, {}).render(*args)
    end

    def modify_template(template, content)
      filename = "#{FIXTURE_LOAD_PATH}/#{template}"
      old_content = File.read(filename)
      begin
        File.open(filename, "wb+") { |f| f.write(content) }
        yield
      ensure
        File.open(filename, "wb+") { |f| f.write(old_content) }
      end
    end
end
