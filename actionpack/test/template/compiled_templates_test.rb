require 'abstract_unit'
require 'controller/fake_models'

class CompiledTemplatesTest < Test::Unit::TestCase
  def setup
    @compiled_templates = ActionView::CompiledTemplates
    @compiled_templates.instance_methods.each do |m|
      @compiled_templates.send(:remove_method, m) if m =~ /^_render_template_/
    end
  end
  
  def test_template_gets_recompiled_when_using_different_keys_in_local_assigns
    assert_equal "one", render(:file => "test/render_file_with_locals_and_default.erb")
    assert_equal "two", render(:file => "test/render_file_with_locals_and_default.erb", :locals => { :secret => "two" })
  end

  def test_template_changes_are_not_reflected_with_cached_templates
    assert_equal "Hello world!", render(:file => "test/hello_world.erb")
    modify_template "test/hello_world.erb", "Goodbye world!" do
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
    end
    assert_equal "Hello world!", render(:file => "test/hello_world.erb")
  end

  def test_template_changes_are_reflected_with_uncached_templates
    assert_equal "Hello world!", render_without_cache(:file => "test/hello_world.erb")
    modify_template "test/hello_world.erb", "Goodbye world!" do
      assert_equal "Goodbye world!", render_without_cache(:file => "test/hello_world.erb")
    end
    assert_equal "Hello world!", render_without_cache(:file => "test/hello_world.erb")
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
      path = ActionView::FileSystemResolverWithFallback.new(FIXTURE_LOAD_PATH)
      view_paths = ActionView::Base.process_view_paths(path)
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
