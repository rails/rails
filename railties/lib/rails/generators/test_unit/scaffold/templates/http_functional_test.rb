require 'test_helper'

<% module_namespacing do -%>
class <%= controller_class_name %>ControllerTest < ActionController::TestCase
  setup do
    @<%= singular_table_name %> = <%= table_name %>(:one)
    @request.accept = "application/json"
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
      post :create, <%= "#{singular_table_name}: { #{attributes_hash} }" %>
    end

    assert_response 201
    assert_not_nil assigns(:<%= singular_table_name %>)
  end

  test "should show <%= singular_table_name %>" do
    get :show, id: @<%= singular_table_name %>
    assert_response :success
  end

  test "should update <%= singular_table_name %>" do
    put :update, id: @<%= singular_table_name %>, <%= "#{singular_table_name}: { #{attributes_hash} }" %>
    assert_response 204
    assert_not_nil assigns(:<%= singular_table_name %>)
  end

  test "should destroy <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete :destroy, id: @<%= singular_table_name %>
    end

    assert_response 204
    assert_not_nil assigns(:<%= singular_table_name %>)
  end
end
<% end -%>
