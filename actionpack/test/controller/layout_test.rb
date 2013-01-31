require 'abstract_unit'
require 'rbconfig'
require 'active_support/core_ext/array/extract_options'

# The view_paths array must be set on Base and not LayoutTest so that LayoutTest's inherited
# method has access to the view_paths array when looking for a layout to automatically assign.
old_load_paths = ActionController::Base.view_paths

ActionView::Template::register_template_handler :mab,
  lambda { |template| template.source.inspect }

ActionController::Base.view_paths = [ File.dirname(__FILE__) + '/../fixtures/layout_tests/' ]

class LayoutTest < ActionController::Base
  def self.controller_path; 'views' end
  def self._implied_layout_name; to_s.underscore.gsub(/_controller$/, '') ; end
  self.view_paths = ActionController::Base.view_paths.dup
end

# Restore view_paths to previous value
ActionController::Base.view_paths = old_load_paths

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

class MultipleExtensions < LayoutTest
end

class LayoutAutoDiscoveryTest < ActionController::TestCase
  def setup
    super
    @request.host = "www.nextangle.com"
  end

  def test_application_layout_is_default_when_no_controller_match
    @controller = ProductController.new
    get :hello
    assert_equal 'layout_test.erb hello.erb', @response.body
  end

  def test_controller_name_layout_name_match
    @controller = ItemController.new
    get :hello
    assert_equal 'item.erb hello.erb', @response.body
  end

  def test_third_party_template_library_auto_discovers_layout
    @controller = ThirdPartyTemplateLibraryController.new
    get :hello
    assert_response :success
    assert_equal 'layouts/third_party_template_library.mab', @response.body
  end

  def test_namespaced_controllers_auto_detect_layouts1
    @controller = ControllerNameSpace::NestedController.new
    get :hello
    assert_equal 'controller_name_space/nested.erb hello.erb', @response.body
  end

  def test_namespaced_controllers_auto_detect_layouts2
    @controller = MultipleExtensions.new
    get :hello
    assert_equal 'multiple_extensions.html.erb hello.erb', @response.body.strip
  end
end

class DefaultLayoutController < LayoutTest
end

class StreamingLayoutController < LayoutTest
  def render(*args)
    options = args.extract_options!
    super(*args, options.merge(:stream => true))
  end
end

class AbsolutePathLayoutController < LayoutTest
  layout File.expand_path(File.expand_path(__FILE__) + '/../../fixtures/layout_tests/layouts/layout_test')
end

class HasOwnLayoutController < LayoutTest
  layout 'item'
end

class PrependsViewPathController < LayoutTest
  def hello
    prepend_view_path File.dirname(__FILE__) + '/../fixtures/layout_tests/alt/'
    render :layout => 'alt'
  end
end

class OnlyLayoutController < LayoutTest
  layout 'item', :only => "hello"
end

class ExceptLayoutController < LayoutTest
  layout 'item', :except => "goodbye"
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

class LayoutSetInResponseTest < ActionController::TestCase
  include ActionView::Template::Handlers

  def test_layout_set_when_using_default_layout
    @controller = DefaultLayoutController.new
    get :hello
    assert_template :layout => "layouts/layout_test"
  end

  def test_layout_set_when_using_streaming_layout
    @controller = StreamingLayoutController.new
    get :hello
    assert_template :hello
  end

  def test_layout_set_when_set_in_controller
    @controller = HasOwnLayoutController.new
    get :hello
    assert_template :layout => "layouts/item"
  end

  def test_layout_only_exception_when_included
    @controller = OnlyLayoutController.new
    get :hello
    assert_template :layout => "layouts/item"
  end

  def test_layout_only_exception_when_excepted
    @controller = OnlyLayoutController.new
    get :goodbye
    assert !@response.body.include?("item.erb"), "#{@response.body.inspect} included 'item.erb'"
  end

  def test_layout_except_exception_when_included
    @controller = ExceptLayoutController.new
    get :hello
    assert_template :layout => "layouts/item"
  end

  def test_layout_except_exception_when_excepted
    @controller = ExceptLayoutController.new
    get :goodbye
    assert !@response.body.include?("item.erb"), "#{@response.body.inspect} included 'item.erb'"
  end

  def test_layout_set_when_using_render
    @controller = SetsLayoutInRenderController.new
    get :hello
    assert_template :layout => "layouts/third_party_template_library"
  end

  def test_layout_is_not_set_when_none_rendered
    @controller = RendersNoLayoutController.new
    get :hello
    assert_template :layout => nil
  end

  def test_layout_is_picked_from_the_controller_instances_view_path
    @controller = PrependsViewPathController.new
    get :hello
    assert_template :layout => /layouts\/alt/
  end

  def test_absolute_pathed_layout
    @controller = AbsolutePathLayoutController.new
    get :hello
    assert_equal "layout_test.erb hello.erb", @response.body.strip
  end
end

class RenderWithTemplateOptionController < LayoutTest
  def hello
    render :template => 'alt/hello'
  end
end

class SetsNonExistentLayoutFile < LayoutTest
  layout "nofile"
end

class LayoutExceptionRaisedTest < ActionController::TestCase
  def test_exception_raised_when_layout_file_not_found
    @controller = SetsNonExistentLayoutFile.new
    assert_raise(ActionView::MissingTemplate) { get :hello }
  end
end

class LayoutStatusIsRendered < LayoutTest
  def hello
    render :status => 401
  end
end

class LayoutStatusIsRenderedTest < ActionController::TestCase
  def test_layout_status_is_rendered
    @controller = LayoutStatusIsRendered.new
    get :hello
    assert_response 401
  end
end

unless RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
  class LayoutSymlinkedTest < LayoutTest
    layout "symlinked/symlinked_layout"
  end

  class LayoutSymlinkedIsRenderedTest < ActionController::TestCase
    def test_symlinked_layout_is_rendered
      @controller = LayoutSymlinkedTest.new
      get :hello
      assert_response 200
      assert_template :layout => "layouts/symlinked/symlinked_layout"
    end
  end
end
