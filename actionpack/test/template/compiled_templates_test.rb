require 'abstract_unit'
require 'controller/fake_models'

class CompiledTemplatesTest < Test::Unit::TestCase
  
  def setup
    @compiled_templates = ActionView::Base::CompiledTemplates

    # first, if we are running the whole test suite with ReloadableTemplates
    # try to undef all the methods through ReloadableTemplate's interfaces
    unless ActionView::Base.cache_template_loading?
      ActionController::Base.view_paths.each do |view_path|
        view_path.paths.values.uniq!.each do |reloadable_template|
          reloadable_template.undef_my_compiled_methods!
        end
      end
    end

    # just purge anything that's left
    @compiled_templates.instance_methods.each do |m|
      @compiled_templates.send(:remove_method, m) if m =~ /^_run_/
    end
  end

  def test_template_gets_compiled
    with_caching(true) do
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      assert_equal 1, @compiled_templates.instance_methods.size
    end
  end

  def test_template_gets_recompiled_when_using_different_keys_in_local_assigns
    with_caching(true) do
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      assert_equal "Hello world!", render(:file => "test/hello_world.erb", :locals => {:foo => "bar"})
      assert_equal 2, @compiled_templates.instance_methods.size
    end
  end

  def test_compiled_template_will_not_be_recompiled_when_rendered_with_identical_local_assigns
    with_caching(true) do
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      ActionView::Template.any_instance.expects(:compile!).never
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
    end
  end

  def test_template_changes_are_not_reflected_with_cached_template_loading
    with_caching(true) do
      with_reloading(false) do
        assert_equal "Hello world!", render(:file => "test/hello_world.erb")
        modify_template "test/hello_world.erb", "Goodbye world!" do
          assert_equal "Hello world!", render(:file => "test/hello_world.erb")
        end
        assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      end
    end
  end

  def test_template_changes_are_reflected_without_cached_template_loading
    with_caching(true) do
      with_reloading(true) do
        assert_equal "Hello world!", render(:file => "test/hello_world.erb")
        modify_template "test/hello_world.erb", "Goodbye world!" do
          reset_mtime_of('test/hello_world.erb')
          assert_equal "Goodbye world!", render(:file => "test/hello_world.erb")
        end
        reset_mtime_of('test/hello_world.erb')
        assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      end
    end
  end

  private
    def render(*args)
      view_paths = ActionController::Base.view_paths
      ActionView::Base.new(view_paths, {}).render(*args)
    end

    def reset_mtime_of(template_name)
      unless ActionView::Base.cache_template_loading?
        ActionController::Base.view_paths.find_template(template_name).previously_last_modified = 10.seconds.ago 
      end
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

    def with_caching(perform_caching)
      old_perform_caching = ActionController::Base.perform_caching
      begin
        ActionController::Base.perform_caching = perform_caching
        yield
      ensure
        ActionController::Base.perform_caching = old_perform_caching
      end
    end

    def with_reloading(reload_templates)
      old_view_paths, old_cache_templates = ActionController::Base.view_paths, ActionView::Base.cache_template_loading
      begin
        ActionView::Base.cache_template_loading = !reload_templates
        ActionController::Base.view_paths = view_paths_for(reload_templates)
        yield
      ensure
        ActionController::Base.view_paths, ActionView::Base.cache_template_loading = old_view_paths, old_cache_templates
      end
    end

    def view_paths_for(reload_templates)
      # reloadable paths are cheap to create
      reload_templates ? ActionView::PathSet.new(CACHED_VIEW_PATHS.map(&:to_s)) : CACHED_VIEW_PATHS
    end
end
