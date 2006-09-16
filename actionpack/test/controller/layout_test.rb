require File.dirname(__FILE__) + '/../abstract_unit'

# The template_root must be set on Base and not LayoutTest so that LayoutTest's inherited method has access to
# the template_root when looking for a layout
ActionController::Base.template_root = File.dirname(__FILE__) + '/../fixtures/layout_tests/'

class LayoutTest < ActionController::Base
  def self.controller_path; 'views' end
end

# Restore template root to be unset
ActionController::Base.template_root = nil

class ProductController < LayoutTest
end

class ItemController < LayoutTest
end

class ThirdPartyTemplateLibraryController < LayoutTest
end

module ControllerNameSpace
end

class ControllerNameSpace::NestedController < LayoutTest
end

class MabView
  def initialize(view)
  end
  
  def render(text, locals = {})
    text
  end
end

ActionView::Base::register_template_handler :mab, MabView

class LayoutAutoDiscoveryTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end
  
  def test_application_layout_is_default_when_no_controller_match
    @controller = ProductController.new
    get :hello
    assert_equal 'layout_test.rhtml hello.rhtml', @response.body
  end
  
  def test_controller_name_layout_name_match
    @controller = ItemController.new
    get :hello
    assert_equal 'item.rhtml hello.rhtml', @response.body
  end
  
  def test_third_party_template_library_auto_discovers_layout
    @controller = ThirdPartyTemplateLibraryController.new
    get :hello
    assert_equal 'layouts/third_party_template_library', @controller.active_layout
    assert_equal 'Mab', @response.body
  end
  
  def test_namespaced_controllers_auto_detect_layouts
    @controller = ControllerNameSpace::NestedController.new
    get :hello
    assert_equal 'layouts/controller_name_space/nested', @controller.active_layout
    assert_equal 'controller_name_space/nested.rhtml hello.rhtml', @response.body
  end
end

class ExemptFromLayoutTest < Test::Unit::TestCase
  def setup
    @controller = LayoutTest.new
  end

  def test_rjs_exempt_from_layout
    assert @controller.send(:template_exempt_from_layout?, 'test.rjs')
  end

  def test_rhtml_and_rxml_not_exempt_from_layout
    assert !@controller.send(:template_exempt_from_layout?, 'test.rhtml')
    assert !@controller.send(:template_exempt_from_layout?, 'test.rxml')
  end

  def test_other_extension_not_exempt_from_layout
    assert !@controller.send(:template_exempt_from_layout?, 'test.random')
  end

  def test_add_extension_to_exempt_from_layout
    ['rpdf', :rpdf].each do |ext|
      assert_nothing_raised do
        ActionController::Base.exempt_from_layout ext
      end
      assert @controller.send(:template_exempt_from_layout?, "test.#{ext}")
    end
  end

  def test_add_regexp_to_exempt_from_layout
    ActionController::Base.exempt_from_layout /\.rdoc/
    assert @controller.send(:template_exempt_from_layout?, 'test.rdoc')
  end
end


class DefaultLayoutController < LayoutTest
end

class HasOwnLayoutController < LayoutTest
  layout 'item'
end

class SetsLayoutInRenderController < LayoutTest
  def hello
    render :layout => 'third_party_template_library'
  end
end

class RendersNoLayoutController < LayoutTest
  def hello
    render :layout => false
  end
end

class LayoutSetInResponseTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_layout_set_when_using_default_layout
    @controller = DefaultLayoutController.new
    get :hello
    assert_equal 'layouts/layout_test', @response.layout
  end
  
  def test_layout_set_when_set_in_controller
    @controller = HasOwnLayoutController.new
    get :hello
    assert_equal 'layouts/item', @response.layout
  end
  
  def test_layout_set_when_using_render
    @controller = SetsLayoutInRenderController.new
    get :hello
    assert_equal 'layouts/third_party_template_library', @response.layout
  end
  
  def test_layout_is_not_set_when_none_rendered
    @controller = RendersNoLayoutController.new
    get :hello
    assert_nil @response.layout
  end
end


class SetsNonExistentLayoutFile < LayoutTest
  layout "nofile.rhtml"
end

class LayoutExceptionRaised < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_exception_raised_when_layout_file_not_found
    @controller = SetsNonExistentLayoutFile.new
    get :hello
    @response.template.class.module_eval { attr_accessor :exception }
    assert_equal ActionController::MissingTemplate, @response.template.exception.class
  end
end
