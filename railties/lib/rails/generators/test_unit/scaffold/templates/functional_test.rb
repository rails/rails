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

  test "should get new" do
    get url_for( controller: :<%= controller_name %>, action: :new )
    assert_response :success
  end

  test "should create <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count') do
      post url_for( controller: :<%= controller_name %>, action: :create, <%= "#{singular_table_name}: { #{attributes_hash} }" %> )
    end

    assert_redirected_to <%= singular_table_name %>_path(<%= class_name %>.last)
  end

  test "should show <%= singular_table_name %>" do
    get url_for( controller: :<%= controller_name %>, action: :show, id: <%= "@#{singular_table_name}" %> )
    assert_response :success
  end

  test "should get edit" do
    get url_for( controller: :<%= controller_name %>, action: :edit, id: <%= "@#{singular_table_name}" %> )
    assert_response :success
  end

  test "should update <%= singular_table_name %>" do
    patch url_for( controller: :<%= controller_name %>, action: :update, id: <%= "@#{singular_table_name}" %>, <%= "#{singular_table_name}: { #{attributes_hash} }" %> )
    assert_redirected_to <%= singular_table_name %>_path(<%= "@#{singular_table_name}" %>)
  end

  test "should destroy <%= singular_table_name %>" do
    assert_difference('<%= class_name %>.count', -1) do
      delete url_for( controller: :<%= controller_name %>, action: :destroy, id: <%= "@#{singular_table_name}" %>  )
    end

    assert_redirected_to <%= index_helper %>_path
  end
end
<% end -%>
