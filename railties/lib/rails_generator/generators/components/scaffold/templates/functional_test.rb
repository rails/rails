require File.dirname(__FILE__) + '<%= '/..' * controller_class_nesting_depth %>/../test_helper'
require '<%= controller_file_path %>_controller'

# Re-raise errors caught by the controller.
class <%= controller_class_name %>Controller; def rescue_action(e) raise e end; end

class <%= controller_class_name %>ControllerTest < Test::Unit::TestCase
  fixtures :<%= table_name %>

  def setup
    @controller = <%= controller_class_name %>Controller.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:<%= table_name %>)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end
  
  def test_should_create_<%= file_name %>
    old_count = <%= class_name %>.count
    post :create, :<%= file_name %> => { }
    assert_equal old_count+1, <%= class_name %>.count
    
    assert_redirected_to <%= file_name %>_path(assigns(:<%= file_name %>))
  end

  def test_should_show_<%= file_name %>
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end
  
  def test_should_update_<%= file_name %>
    put :update, :id => 1, :<%= file_name %> => { }
    assert_redirected_to <%= file_name %>_path(assigns(:<%= file_name %>))
  end
  
  def test_should_destroy_<%= file_name %>
    old_count = <%= class_name %>.count
    delete :destroy, :id => 1
    assert_equal old_count-1, <%= class_name %>.count
    
    assert_redirected_to <%= table_name %>_path
  end
end
