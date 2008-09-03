require 'abstract_unit'

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
    render :inline => "Ring, ring: <%= render_component(:controller => 'callee', :action => 'being_called') %>"
  end

  def internal_caller
    render :inline => "Are you there? <%= render_component(:action => 'internal_callee') %>"
  end

  def internal_callee
    render :text => "Yes, ma'am"
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
    render :inline => "<%= render_component(:controller => 'callee', :action => 'redirected') %>"
  end

  def rescue_action(e) raise end
end

class CalleeController < ActionController::Base
  def being_called
    render :text => "#{params[:name] || "Lady"} of the House, speaking"
  end

  def blowing_up
    render :text => "It's game over, man, just game over, man!", :status => 500
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
    assert_deprecated do
      get :calling_from_controller
      assert_equal "Lady of the House, speaking", @response.body
    end
  end

  def test_calling_from_controller_with_params
    assert_deprecated do
      get :calling_from_controller_with_params
      assert_equal "David of the House, speaking", @response.body
    end
  end

  def test_calling_from_controller_with_different_status_code
    assert_deprecated do
      get :calling_from_controller_with_different_status_code
      assert_equal 500, @response.response_code
    end
  end

  def test_calling_from_template
    assert_deprecated do
      get :calling_from_template
      assert_equal "Ring, ring: Lady of the House, speaking", @response.body
    end
  end

  def test_etag_is_set_for_parent_template_when_calling_from_template
    assert_deprecated do
      get :calling_from_template
      expected_etag = etag_for("Ring, ring: Lady of the House, speaking")
      assert_equal expected_etag, @response.headers['ETag']
    end
  end

  def test_internal_calling
    assert_deprecated do
      get :internal_caller
      assert_equal "Are you there? Yes, ma'am", @response.body
    end
  end

  def test_flash
    assert_deprecated do
      get :set_flash
      assert_equal 'My stoney baby', flash[:notice]
      get :use_flash
      assert_equal 'My stoney baby', @response.body
      get :use_flash
      assert_equal 'no flash', @response.body
    end
  end

  def test_component_redirect_redirects
    assert_deprecated do
      get :calling_redirected
      assert_redirected_to :controller=>"callee", :action => "being_called"
    end
  end

  def test_component_multiple_redirect_redirects
    test_component_redirect_redirects
    test_internal_calling
  end

  def test_component_as_string_redirect_renders_redirected_action
    assert_deprecated do
      get :calling_redirected_as_string
      assert_equal "Lady of the House, speaking", @response.body
    end
  end

  protected
    def etag_for(text)
      %("#{Digest::MD5.hexdigest(text)}")
    end
end
