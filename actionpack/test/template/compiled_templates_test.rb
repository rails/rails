require 'abstract_unit'
require 'controller/fake_models'

class CompiledTemplatesTest < Test::Unit::TestCase

  def setup
    @explicit_view_paths = nil
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
        end
        assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      end
    end
  end

  def test_template_becomes_missing_if_deleted_without_cached_template_loading
    with_reloading(true) do
      assert_equal 'Hello world!', render(:file => 'test/hello_world.erb')
      delete_template 'test/hello_world.erb' do
        assert_raise(ActionView::MissingTemplate) { render(:file => 'test/hello_world.erb') }
      end
      assert_equal 'Hello world!', render(:file => 'test/hello_world.erb')
    end
  end

  def test_swapping_template_handler_is_working_without_cached_template_loading
    with_reloading(true) do
      assert_equal 'Hello world!', render(:file => 'test/hello_world')
      delete_template 'test/hello_world.erb' do
        rename_template 'test/hello_world_from_rxml.builder', 'test/hello_world.builder' do
          assert_equal "<html>\n  <p>Hello</p>\n</html>\n", render(:file => 'test/hello_world')
        end
      end
      assert_equal 'Hello world!', render(:file => 'test/hello_world')
    end
  end

  def test_adding_localized_template_will_take_precedence_without_cached_template_loading
    with_reloading(true) do
      assert_equal 'Hello world!', render(:file => 'test/hello_world')
      rename_template 'test/hello_world.da.html.erb', 'test/hello_world.en.html.erb' do
        assert_equal 'Hey verden', render(:file => 'test/hello_world')
      end
    end
  end

  def test_deleting_localized_template_will_fall_back_to_non_localized_template_without_cached_template_loading
    with_reloading(true) do
      rename_template 'test/hello_world.da.html.erb', 'test/hello_world.en.html.erb' do
        assert_equal 'Hey verden', render(:file => 'test/hello_world')
        delete_template 'test/hello_world.en.html.erb' do
          assert_equal 'Hello world!', render(:file => 'test/hello_world')
        end
        assert_equal 'Hey verden', render(:file => 'test/hello_world')
      end
    end
  end

  def test_parallel_reloadable_view_paths_are_working
    with_reloading(true) do
      view_paths_copy = new_reloadable_view_paths
      assert_equal 'Hello world!', render(:file => 'test/hello_world')
      with_view_paths(view_paths_copy, new_reloadable_view_paths) do
        assert_equal 'Hello world!', render(:file => 'test/hello_world')
      end
      modify_template 'test/hello_world.erb', 'Goodbye world!' do
        assert_equal 'Goodbye world!', render(:file => 'test/hello_world')
        modify_template 'test/hello_world.erb', 'So long, world!' do
          with_view_paths(view_paths_copy, new_reloadable_view_paths) do
            assert_equal 'So long, world!', render(:file => 'test/hello_world')
          end
          assert_equal 'So long, world!', render(:file => 'test/hello_world')
        end
      end
    end
  end

  private
    def render(*args)
      view_paths = @explicit_view_paths || ActionController::Base.view_paths
      ActionView::Base.new(view_paths, {}).render(*args)
    end

    def with_view_paths(*args)
      args.each do |view_paths|
        begin
          @explicit_view_paths = view_paths
          yield
        ensure
          @explicit_view_paths = nil
        end
      end
    end

    def reset_mtime_of(template_name, view_paths_to_use)
      view_paths_to_use.find_template(template_name).previously_last_modified = 10.seconds.ago unless ActionView::Base.cache_template_loading?
    end

    def modify_template(template, content, view_paths_to_use = ActionController::Base.view_paths)
      filename = filename_for(template)
      old_content = File.read(filename)
      begin
        File.open(filename, "wb+") { |f| f.write(content) }
        reset_mtime_of(template, view_paths_to_use)
        yield
      ensure
        File.open(filename, "wb+") { |f| f.write(old_content) }
        reset_mtime_of(template, view_paths_to_use)
      end
    end

    def filename_for(template)
      File.join(FIXTURE_LOAD_PATH, template)
    end

    def rename_template(old_name, new_name)
      File.rename(filename_for(old_name), filename_for(new_name))
      yield
    ensure
      File.rename(filename_for(new_name), filename_for(old_name))
    end

    def delete_template(template, &block)
      rename_template(template, File.join(File.dirname(template), "__#{File.basename(template)}"), &block)
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

    def with_reloading(reload_templates, view_paths_owner = ActionController::Base)
      old_view_paths, old_cache_templates = view_paths_owner.view_paths, ActionView::Base.cache_template_loading
      begin
        ActionView::Base.cache_template_loading = !reload_templates
        view_paths_owner.view_paths = view_paths_for(reload_templates)
        yield
      ensure
        view_paths_owner.view_paths, ActionView::Base.cache_template_loading = old_view_paths, old_cache_templates
      end
    end

    def new_reloadable_view_paths
      ActionView::PathSet.new(CACHED_VIEW_PATHS.map(&:to_s))
    end

    def view_paths_for(reload_templates)
      # reloadable paths are cheap to create
      reload_templates ? new_reloadable_view_paths : CACHED_VIEW_PATHS
    end
end
