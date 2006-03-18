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