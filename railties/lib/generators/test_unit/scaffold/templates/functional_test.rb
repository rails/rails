require 'test_helper'

class <%= controller_class_name %>ControllerTest < ActionController::TestCase
  setup do
    @<%= file_name %> = <%= table_name %>(:one)
  end

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
      post :create, :<%= file_name %> => @<%= file_name %>.attributes
    end

    assert_redirected_to <%= file_name %>_path(assigns(:<%= file_name %>))
  end

  test "should show <%= file_name %>" do
    get :show, :id => @<%= file_name %>.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @<%= file_name %>.to_param
    assert_response :success
  end

  test "should update <%= file_name %>" do
    put :update, :id => @<%= file_name %>.to_param, :<%= file_name %> => @<%= file_name %>.attributes
    assert_redirected_to <%= file_name %>_path(assigns(:<%= file_name %>))
  end

  test "should destroy <%= file_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete :destroy, :id => @<%= file_name %>.to_param
    end

    assert_redirected_to <%= table_name %>_path
  end
end
