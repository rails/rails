require File.dirname(__FILE__) + '<%= "/.." * controller_class_nesting_depth %>/../test_helper'
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

<% for action in unscaffolded_actions -%>
  def test_<%= action %>
    get :<%= action %>
    assert_rendered_file '<%= action %>'
  end

<% end -%>
<% unless suffix -%>
  def test_index
    get :index
    assert_rendered_file 'list'
  end

<% end -%>
  def test_list<%= suffix %>
    get :list<%= suffix %>
    assert_rendered_file 'list<%= suffix %>'
    assert_template_has '<%= plural_name %>'
  end

  def test_show<%= suffix %>
    get :show<%= suffix %>, 'id' => 1
    assert_rendered_file 'show'
    assert_template_has '<%= singular_name %>'
    assert_valid_record '<%= singular_name %>'
  end

  def test_new<%= suffix %>
    get :new<%= suffix %>
    assert_rendered_file 'new<%= suffix %>'
    assert_template_has '<%= singular_name %>'
  end

  def test_create
    num_<%= plural_name %> = <%= model_name %>.find_all.size

    post :create<%= suffix %>, '<%= singular_name %>' => { }
    assert_redirected_to :action => 'list<%= suffix %>'

    assert_equal num_<%= plural_name %> + 1, <%= model_name %>.find_all.size
  end

  def test_edit<%= suffix %>
    get :edit<%= suffix %>, 'id' => 1
    assert_rendered_file 'edit<%= suffix %>'
    assert_template_has '<%= singular_name %>'
    assert_valid_record '<%= singular_name %>'
  end

  def test_update<%= suffix %>
    post :update<%= suffix %>, 'id' => 1
    assert_redirected_to :action => 'show<%= suffix %>', :id => 1
  end

  def test_destroy<%= suffix %>
    assert_not_nil <%= model_name %>.find(1)

    post :destroy, 'id' => 1
    assert_redirected_to :action => 'list<%= suffix %>'

    assert_raise(ActiveRecord::RecordNotFound) {
      <%= singular_name %> = <%= model_name %>.find(1)
    }
  end
end
