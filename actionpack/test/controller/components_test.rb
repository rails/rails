require File.dirname(__FILE__) + '/../abstract_unit'

class CallerController < ActionController::Base
  def calling_from_controller
    render_component(:controller => "callee", :action => "being_called")
  end

  def calling_from_controller_with_params
    render_component(:controller => "callee", :action => "being_called", :params => { "name" => "David" })
  end

  def calling_from_controller_with_different_status_code
    render_component(:controller => "callee", :action => "blowing_up")
  end

  def calling_from_template
    render_template "Ring, ring: <%= render_component(:controller => 'callee', :action => 'being_called') %>"
  end

  def internal_caller
    render_template "Are you there? <%= render_component(:action => 'internal_callee') %>"
  end
  
  def internal_callee
    render_text "Yes, ma'am"
  end

  def set_flash
    render_component(:controller => "callee", :action => "set_flash")
  end

  def use_flash
    render_component(:controller => "callee", :action => "use_flash")
  end
  
  def calling_redirected
    render_component(:controller => "callee", :action => "redirected")
  end
  
  def calling_redirected_as_string
    render_template "<%= render_component(:controller => 'callee', :action => 'redirected') %>"
  end

  def rescue_action(e) raise end
end

class CalleeController < ActionController::Base
  def being_called
    render_text "#{params[:name] || "Lady"} of the House, speaking"
  end
  
  def blowing_up
    render_text "It's game over, man, just game over, man!", "500 Internal Server Error"
  end
  
  def set_flash
    flash[:notice] = 'My stoney baby'
    render :text => 'flash is set'
  end
  
  def use_flash
    render :text => flash[:notice] || 'no flash'
  end
  
  def redirected
    redirect_to :controller => "callee", :action => "being_called"
  end

  def rescue_action(e) raise end
end

class ComponentsTest < Test::Unit::TestCase
  def setup
    @controller = CallerController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_calling_from_controller
    get :calling_from_controller
    assert_equal "Lady of the House, speaking", @response.body
  end

  def test_calling_from_controller_with_params
    get :calling_from_controller_with_params
    assert_equal "David of the House, speaking", @response.body
  end
  
  def test_calling_from_controller_with_different_status_code
    get :calling_from_controller_with_different_status_code
    assert_equal 500, @response.response_code
  end

  def test_calling_from_template
    get :calling_from_template
    assert_equal "Ring, ring: Lady of the House, speaking", @response.body
  end
  
  def test_internal_calling
    get :internal_caller
    assert_equal "Are you there? Yes, ma'am", @response.body
  end
  
  def test_flash
    get :set_flash
    assert_equal 'My stoney baby', flash[:notice]
    get :use_flash
    assert_equal 'My stoney baby', @response.body
    get :use_flash
    assert_equal 'no flash', @response.body
  end
  
  def test_component_redirect_redirects
    get :calling_redirected
    
    assert_redirected_to :action => "being_called"
  end
  
  def test_component_multiple_redirect_redirects
    test_component_redirect_redirects
    test_internal_calling
  end
  
  def test_component_as_string_redirect_renders_redirecte_action
    get :calling_redirected_as_string
    
    assert_equal "Lady of the House, speaking", @response.body
  end
end

module A
  module B
    module C
      class NestedController < ActionController::Base
        # Stub for uses_component_template_root
        def self.caller
          [ '/path/to/active_support/deprecation.rb:93:in `uses_component_template_root',
            './test/fixtures/a/b/c/nested_controller.rb' ]
        end
      end
    end
  end
end

class UsesComponentTemplateRootTest < Test::Unit::TestCase
  def test_uses_component_template_root
    assert_deprecated 'uses_component_template_root' do
      assert_equal './test/fixtures/', A::B::C::NestedController.uses_component_template_root
    end
  end
end
