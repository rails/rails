require 'abstract_unit'
require 'controller/fake_models'

class CompiledTemplatesTest < Test::Unit::TestCase
  def setup
    @compiled_templates = ActionView::Base::CompiledTemplates
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

  def test_compiled_template_will_always_be_recompiled_when_template_is_not_cached
    with_caching(false) do
      ActionView::Template.any_instance.expects(:recompile?).times(3).returns(true)
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "#{FIXTURE_LOAD_PATH}/test/hello_world.erb")
      ActionView::Template.any_instance.expects(:compile!).times(3)
      3.times { assert_equal "Hello world!", render(:file => "#{FIXTURE_LOAD_PATH}/test/hello_world.erb") }
      assert_equal 1, @compiled_templates.instance_methods.size
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
          assert_equal "Goodbye world!", render(:file => "test/hello_world.erb")
          sleep(1) # Need to sleep so that the timestamp actually changes
        end
        assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      end
    end
  end

  private
    def render(*args)
      view_paths = ActionController::Base.view_paths
      assert_equal ActionView::Template::Path, view_paths.first.class
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
      old_cache_template_loading = ActionView::Base.cache_template_loading
      begin
        ActionView::Base.cache_template_loading = !reload_templates
        yield
      ensure
        ActionView::Base.cache_template_loading = old_cache_template_loading
      end
    end
end
