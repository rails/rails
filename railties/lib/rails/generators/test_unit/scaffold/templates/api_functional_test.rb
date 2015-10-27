require 'test_helper'

<% module_namespacing do -%>
class <%= controller_class_name %>ControllerTest < ActionDispatch::IntegrationTest
  setup do
    @<%= singular_table_name %> = <%= fixture_name %>(:one)
<% if mountable_engine? -%>
    @routes = Engine.routes
<% end -%>
  end

  test "should get index" do
    get url_for( controller: :<%= controller_name %>, action: :index )
    assert_response :success
  end

  test "should create <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count') do
      post url_for( controller: :<%= controller_name %>, action: :create, <%= "#{singular_table_name}: { #{attributes_hash} }" %> )
    end

    assert_response 201
  end

  test "should show <%= singular_table_name %>" do
    get url_for( controller: :<%= controller_name %>, action: :show, id: <%= "@#{singular_table_name}" %> )
    assert_response :success
  end

  test "should update <%= singular_table_name %>" do
    patch url_for( controller: :<%= controller_name %>, action: :update, id: <%= "@#{singular_table_name}" %>, <%= "#{singular_table_name}: { #{attributes_hash} }" %> )
    assert_response 200
  end

  test "should destroy <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete url_for( controller: :<%= controller_name %>, action: :destroy, id: <%= "@#{singular_table_name}" %> )
    end

    assert_response 204
  end
end
<% end -%>
