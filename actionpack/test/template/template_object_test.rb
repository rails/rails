require 'abstract_unit'

class TemplateObjectTest < Test::Unit::TestCase
  LOAD_PATH_ROOT = File.join(File.dirname(__FILE__), '..', 'fixtures')
  ActionView::TemplateFinder.process_view_paths(LOAD_PATH_ROOT)
  
  class TemplateTest < Test::Unit::TestCase
    def setup
      @view = ActionView::Base.new(LOAD_PATH_ROOT)
      @path = "test/hello_world.erb"
    end
    
    def test_should_create_valid_template
      template = ActionView::Template.new(@view, @path, true)
      
      assert_kind_of ActionView::TemplateHandlers::ERB, template.handler
      assert_equal "test/hello_world.erb", template.path
      assert_nil template.instance_variable_get(:"@source")
      assert_equal "erb", template.extension
    end
    
    uses_mocha 'Template preparation tests' do
      
      def test_should_prepare_template_properly
        template = ActionView::Template.new(@view, @path, true)
        view = template.instance_variable_get(:"@view")
        
        view.expects(:evaluate_assigns)
        template.handler.expects(:compile_template).with(template)
        view.expects(:method_names).returns({})
        
        template.prepare!
      end
      
    end
  end
  
  class PartialTemplateTest < Test::Unit::TestCase
    def setup
      @view = ActionView::Base.new(LOAD_PATH_ROOT)
      @path = "test/partial_only"
    end
    
    def test_should_create_valid_partial_template
      template = ActionView::PartialTemplate.new(@view, @path, nil)
      
      assert_equal "test/_partial_only", template.path
      assert_equal :partial_only, template.variable_name
      
      assert template.locals.has_key?(:object)
      assert template.locals.has_key?(:partial_only)
    end
    
    def test_partial_with_errors
      template = ActionView::PartialTemplate.new(@view, 'test/raise', nil)
      assert_raise(ActionView::TemplateError) { template.render_template }
    end
    
    uses_mocha 'Partial template preparation tests' do
      def test_should_prepare_on_initialization
        ActionView::PartialTemplate.any_instance.expects(:prepare!)
        template = ActionView::PartialTemplate.new(@view, @path, 1)
      end
    end
  end
  
  class PartialTemplateFallbackTest < Test::Unit::TestCase
    def setup
      @view = ActionView::Base.new(LOAD_PATH_ROOT)
      @path = 'test/layout_for_partial'
    end

    def test_default
      template = ActionView::PartialTemplate.new(@view, @path, nil)
      assert_equal 'test/_layout_for_partial', template.path
      assert_equal 'erb', template.extension
      assert_equal :html, @view.template_format
    end

    def test_js
      @view.template_format = :js
      template = ActionView::PartialTemplate.new(@view, @path, nil)
      assert_equal 'test/_layout_for_partial', template.path
      assert_equal 'erb', template.extension
      assert_equal :html, @view.template_format
    end

    def test_xml
      @view.template_format = :xml
      assert_raise ActionView::MissingTemplate do
        ActionView::PartialTemplate.new(@view, @path, nil)
      end
    end
  end
end
