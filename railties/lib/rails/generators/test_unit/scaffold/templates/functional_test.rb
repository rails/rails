require 'test_helper'

class <%= controller_class_name %>ControllerTest < ActionController::TestCase
<% unless options[:singleton] -%>
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:<%= table_name %>)
  end
<% end -%>

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create <%= file_name %>" do
    assert_difference('<%= class_name %>.count') do
      post :create, :<%= file_name %> => { }
    end

    assert_redirected_to <%= file_name %>_path(assigns(:<%= file_name %>))
  end

  test "should show <%= file_name %>" do
    get :show, :id => <%= table_name %>(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => <%= table_name %>(:one).to_param
    assert_response :success
  end

  test "should update <%= file_name %>" do
    put :update, :id => <%= table_name %>(:one).to_param, :<%= file_name %> => { }
    assert_redirected_to <%= file_name %>_path(assigns(:<%= file_name %>))
  end

  test "should destroy <%= file_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete :destroy, :id => <%= table_name %>(:one).to_param
    end

    assert_redirected_to <%= table_name %>_path
  end
end
