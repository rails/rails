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

    @first_id = <%= plural_name %>(:first).id
  end

<% for action in unscaffolded_actions -%>
  def test_<%= action %>
    get :<%= action %>
    assert_response :success
    assert_template '<%= action %>'
  end

<% end -%>
<% unless suffix -%>
  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

<% end -%>
  def test_list<%= suffix %>
    get :list<%= suffix %>

    assert_response :success
    assert_template 'list<%= suffix %>'

    assert_not_nil assigns(:<%= plural_name %>)
  end

  def test_show<%= suffix %>
    get :show<%= suffix %>, :id => @first_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:<%= singular_name %>)
    assert assigns(:<%= singular_name %>).valid?
  end

  def test_new<%= suffix %>
    get :new<%= suffix %>

    assert_response :success
    assert_template 'new<%= suffix %>'

    assert_not_nil assigns(:<%= singular_name %>)
  end

  def test_create
    num_<%= plural_name %> = <%= model_name %>.count

    post :create<%= suffix %>, :<%= singular_name %> => {}

    assert_response :redirect
    assert_redirected_to :action => 'list<%= suffix %>'

    assert_equal num_<%= plural_name %> + 1, <%= model_name %>.count
  end

  def test_edit<%= suffix %>
    get :edit<%= suffix %>, :id => @first_id

    assert_response :success
    assert_template 'edit<%= suffix %>'

    assert_not_nil assigns(:<%= singular_name %>)
    assert assigns(:<%= singular_name %>).valid?
  end

  def test_update<%= suffix %>
    post :update<%= suffix %>, :id => @first_id
    assert_response :redirect
    assert_redirected_to :action => 'show<%= suffix %>', :id => @first_id
  end

  def test_destroy<%= suffix %>
    assert_nothing_raised {
      <%= model_name %>.find(@first_id)
    }

    post :destroy, :id => @first_id
    assert_response :redirect
    assert_redirected_to :action => 'list<%= suffix %>'

    assert_raise(ActiveRecord::RecordNotFound) {
      <%= model_name %>.find(@first_id)
    }
  end
end
