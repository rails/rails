require 'test_helper'

class <%= controller_class_name %>ControllerTest < ActionController::TestCase
  setup do
    @<%= singular_table_name %> = <%= table_name %>(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:<%= table_name %>)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count') do
      post :create, :<%= singular_table_name %> => @<%= singular_table_name %>.attributes
    end

    assert_redirected_to <%= singular_table_name %>_path(assigns(:<%= singular_table_name %>))
  end

  test "should show <%= singular_table_name %>" do
    get :show, :id => @<%= singular_table_name %>.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @<%= singular_table_name %>.to_param
    assert_response :success
  end

  test "should update <%= singular_table_name %>" do
    put :update, :id => @<%= singular_table_name %>.to_param, :<%= singular_table_name %> => @<%= singular_table_name %>.attributes
    assert_redirected_to <%= singular_table_name %>_path(assigns(:<%= singular_table_name %>))
  end

  test "should destroy <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete :destroy, :id => @<%= singular_table_name %>.to_param
    end

    assert_redirected_to <%= index_helper %>_path
  end
end
