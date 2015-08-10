require 'test_helper'

<% module_namespacing do -%>
class <%= controller_class_name %>ControllerTest < ActionController::TestCase
  setup do
    @<%= singular_table_name %> = <%= fixture_name %>(:one)
<% if mountable_engine? -%>
    @routes = Engine.routes
<% end -%>
  end

  test "should get index" do
    get :index
    assert_response :success
  end

  test "should create <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count') do
      post :create, params: { <%= "#{singular_table_name}: { #{attributes_hash} }" %> }
    end

    assert_response 201
  end

  test "should show <%= singular_table_name %>" do
    get :show, params: { id: <%= "@#{singular_table_name}" %> }
    assert_response :success
  end

  test "should update <%= singular_table_name %>" do
    patch :update, params: { id: <%= "@#{singular_table_name}" %>, <%= "#{singular_table_name}: { #{attributes_hash} }" %> }
    assert_response 200
  end

  test "should destroy <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete :destroy, params: { id: <%= "@#{singular_table_name}" %> }
    end

    assert_response 204
  end
end
<% end -%>
