require File.dirname(__FILE__) + '/../test_helper'
require '<%= @controller_name %>_controller'

# Re-raise errors caught by the controller.
class <%= @controller_class_name %>Controller; def rescue_action(e) raise e end; end

class <%= @controller_class_name %>ControllerTest < Test::Unit::TestCase
  fixtures :<%= table_name %>

  def setup
    @controller = <%= @controller_class_name %>Controller.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
  end

<% for action in unscaffolded_actions -%>
  def test_<%= action %>
    process :<%= action %>
    assert_rendered_file '<%= action %>'
  end

<% end -%>
<% unless suffix -%>
  def test_index
    process :index
    assert_rendered_file 'list'
  end

<% end -%>
  def test_list<%= suffix %>
    process :list<%= suffix %>
    assert_rendered_file 'list<%= suffix %>'
    assert_template_has '<%= plural_name %>'
  end

  def test_show<%= suffix %>
    process :show<%= suffix %>, 'id' => 1
    assert_rendered_file 'show'
    assert_template_has '<%= singular_name %>'
    assert_valid_record '<%= singular_name %>'
  end

  def test_new<%= suffix %>
    process :new<%= suffix %>
    assert_rendered_file 'new<%= suffix %>'
    assert_template_has '<%= singular_name %>'
  end

  def test_create
    num_<%= plural_name %> = <%= class_name %>.find_all.size

    process :create<%= suffix %>, '<%= singular_name %>' => { }
    assert_redirected_to :action => 'list<%= suffix %>'

    assert_equal num_<%= plural_name %> + 1, <%= class_name %>.find_all.size
  end

  def test_edit<%= suffix %>
    process :edit<%= suffix %>, 'id' => 1
    assert_rendered_file 'edit<%= suffix %>'
    assert_template_has '<%= singular_name %>'
    assert_valid_record '<%= singular_name %>'
  end

  def test_update<%= suffix %>
    process :update<%= suffix %>, '<%= singular_name %>' => { 'id' => 1 }
    assert_redirected_to :action => 'show<%= suffix %>', :id => 1
  end

  def test_destroy<%= suffix %>
    assert_not_nil <%= class_name %>.find(1)

    process :destroy, 'id' => 1
    assert_redirected_to :action => 'list<%= suffix %>'

    assert_raise(ActiveRecord::RecordNotFound) {
      <%= singular_name %> = <%= class_name %>.find(1)
    }
  end
end
