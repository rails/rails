require 'abstract_unit'
require 'controller/fake_models'

uses_mocha 'TestTemplateRecompilation' do
  class CompiledTemplatesTest < Test::Unit::TestCase
    def setup
      @compiled_templates = ActionView::Base::CompiledTemplates
      @compiled_templates.instance_methods.each do |m|
        @compiled_templates.send(:remove_method, m) if m =~ /^_run_/
      end
    end

    def test_template_gets_compiled
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      assert_equal 1, @compiled_templates.instance_methods.size
    end

    def test_template_gets_recompiled_when_using_different_keys_in_local_assigns
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      assert_equal "Hello world!", render(:file => "test/hello_world.erb", :locals => {:foo => "bar"})
      assert_equal 2, @compiled_templates.instance_methods.size
    end

    def test_compiled_template_will_not_be_recompiled_when_rendered_with_identical_local_assigns
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
      ActionView::Template.any_instance.expects(:compile!).never
      assert_equal "Hello world!", render(:file => "test/hello_world.erb")
    end

    def test_compiled_template_will_always_be_recompiled_when_template_is_not_cached
      ActionView::Template.any_instance.expects(:recompile?).times(3).returns(true)
      assert_equal 0, @compiled_templates.instance_methods.size
      assert_equal "Hello world!", render(:file => "#{FIXTURE_LOAD_PATH}/test/hello_world.erb")
      ActionView::Template.any_instance.expects(:compile!).times(3)
      3.times { assert_equal "Hello world!", render(:file => "#{FIXTURE_LOAD_PATH}/test/hello_world.erb") }
      assert_equal 1, @compiled_templates.instance_methods.size
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
        assert_equal ActionView::Template::EagerPath, view_paths.first.class
        ActionView::Base.new(view_paths, {}).render(*args)
      end

      def render_without_cache(*args)
        path = ActionView::Template::Path.new(FIXTURE_LOAD_PATH)
        view_paths = ActionView::Base.process_view_paths(path)
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
  end
end
