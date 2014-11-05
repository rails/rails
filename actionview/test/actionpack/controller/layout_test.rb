require 'abstract_unit'
require 'rbconfig'
require 'active_support/core_ext/array/extract_options'

# The view_paths array must be set on Base and not LayoutTestController so that LayoutTestController's inherited
# method has access to the view_paths array when looking for a layout to automatically assign.
old_load_paths = ActionController::Base.view_paths

ActionController::Base.view_paths = [ File.dirname(__FILE__) + '/../../fixtures/actionpack/layout_tests/' ]

class LayoutTestController < ActionController::Base
  def self._implied_layout_name; to_s.underscore.gsub(/_controller$/, '') ; end
  self.view_paths = ActionController::Base.view_paths.dup

  def hello
    render 'views/hello.erb'
  end

  def goodbye
    render 'views/goodbye'
  end
end

module TemplateHandlerHelper
  def with_template_handler(*extensions, handler)
    ActionView::Template.register_template_handler(*extensions, handler)
    yield
  ensure
    ActionView::Template.unregister_template_handler(*extensions)
  end
end

# Restore view_paths to previous value
ActionController::Base.view_paths = old_load_paths

class ProductController < LayoutTestController
end

class ItemController < LayoutTestController
end

class ThirdPartyTemplateLibraryController < LayoutTestController
end

module ControllerNameSpace
end

class ControllerNameSpace::NestedController < LayoutTestController
end

class MultipleExtensionsController < LayoutTestController
end

class LayoutAutoDiscoveryTest < ActionController::TestCase
  include TemplateHandlerHelper

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
    with_template_handler :mab, lambda { |template| template.source.inspect } do
      @controller = ThirdPartyTemplateLibraryController.new
      get :hello
      assert_response :success
      assert_equal 'layouts/third_party_template_library.mab', @response.body
    end
  end

  def test_namespaced_controllers_auto_detect_layouts1
    @controller = ControllerNameSpace::NestedController.new
    get :hello
    assert_equal 'controller_name_space/nested.erb hello.erb', @response.body
  end

  def test_namespaced_controllers_auto_detect_layouts2
    @controller = MultipleExtensionsController.new
    get :hello
    assert_equal 'multiple_extensions.html.erb hello.erb', @response.body.strip
  end
end

class DefaultLayoutController < LayoutTestController
end

class StreamingLayoutController < LayoutTestController
  def render(*args)
    options = args.extract_options!
    super(*args, options.merge(:stream => true))
  end
end

class AbsolutePathLayoutController < LayoutTestController
  layout File.expand_path(File.expand_path(__FILE__) + '/../../../fixtures/actionpack/layout_tests/layouts/layout_test')
end

class HasOwnLayoutController < LayoutTestController
  layout 'item'
end

class HasNilLayoutSymbolController < LayoutTestController
  layout :nilz

  def nilz
    nil
  end
end

class HasNilLayoutProcController < LayoutTestController
  layout proc { nil }
end

class PrependsViewPathController < LayoutTestController
  def hello
    prepend_view_path File.dirname(__FILE__) + '/../../fixtures/actionpack/layout_tests/alt/'
    render 'views/hello', :layout => 'alt'
  end
end

class OnlyLayoutController < LayoutTestController
  layout 'item', :only => "hello"
end

class ExceptLayoutController < LayoutTestController
  layout 'item', :except => "goodbye"
end

class SetsLayoutInRenderController < LayoutTestController
  def hello
    render 'views/hello', :layout => 'third_party_template_library'
  end
end

class RendersNoLayoutController < LayoutTestController
  def hello
    render 'views/hello', :layout => false
  end
end

class LayoutSetInResponseTest < ActionController::TestCase
  include ActionView::Template::Handlers
  include TemplateHandlerHelper

  def test_layout_set_when_using_default_layout
    @controller = DefaultLayoutController.new
    get :hello
    assert_template :layout => "layouts/layout_test"
  end

  def test_layout_set_when_using_streaming_layout
    @controller = StreamingLayoutController.new
    get :hello
    assert_template 'views/hello.erb', layout: 'layouts/layout_test'
  end

  def test_layout_set_when_set_in_controller
    @controller = HasOwnLayoutController.new
    get :hello
    assert_template :layout => "layouts/item"
  end

  def test_layout_symbol_set_in_controller_returning_nil_falls_back_to_default
    @controller = HasNilLayoutSymbolController.new
    get :hello
    assert_template layout: "layouts/layout_test"
  end

  def test_layout_proc_set_in_controller_returning_nil_falls_back_to_default
    @controller = HasNilLayoutProcController.new
    get :hello
    assert_template layout: "layouts/layout_test"
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
    with_template_handler :mab, lambda { |template| template.source.inspect } do
      @controller = SetsLayoutInRenderController.new
      get :hello
      assert_template :layout => "layouts/third_party_template_library"
    end
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

class SetsNonExistentLayoutFileController < LayoutTestController
  layout "nofile"
end

class LayoutExceptionRaisedTest < ActionController::TestCase
  def test_exception_raised_when_layout_file_not_found
    @controller = SetsNonExistentLayoutFileController.new
    assert_raise(ActionView::MissingTemplate) { get :hello }
  end
end

class LayoutStatusIsRenderedController < LayoutTestController
  def hello
    render 'views/hello.erb', :status => 401
  end
end

class LayoutStatusIsRenderedTest < ActionController::TestCase
  def test_layout_status_is_rendered
    @controller = LayoutStatusIsRenderedController.new
    get :hello
    assert_response 401
  end
end

unless RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
  class LayoutSymlinkedTestController < LayoutTestController
    layout "symlinked/symlinked_layout"
  end

  class LayoutSymlinkedIsRenderedTest < ActionController::TestCase
    def test_symlinked_layout_is_rendered
      @controller = LayoutSymlinkedTestController.new
      get :hello
      assert_response 200
      assert_template :layout => "layouts/symlinked/symlinked_layout"
    end
  end
end
