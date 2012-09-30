require 'abstract_unit'
require 'action_controller/vendor/html-scanner'
require 'controller/fake_controllers'

class ActionPackAssertionsController < ActionController::Base

  def nothing() head :ok end

  def hello_world() render :template => "test/hello_world"; end
  def hello_repeating_in_path() render :template => "test/hello/hello"; end

  def hello_xml_world() render :template => "test/hello_xml_world"; end

  def hello_xml_world_pdf
    self.content_type = "application/pdf"
    render :template => "test/hello_xml_world"
  end

  def hello_xml_world_pdf_header
    response.headers["Content-Type"] = "application/pdf; charset=utf-8"
    render :template => "test/hello_xml_world"
  end

  def partial() render :partial => 'test/partial'; end

  def redirect_internal() redirect_to "/nothing"; end

  def redirect_to_action() redirect_to :action => "flash_me", :id => 1, :params => { "panda" => "fun" }; end

  def redirect_to_controller() redirect_to :controller => "elsewhere", :action => "flash_me"; end

  def redirect_to_controller_with_symbol() redirect_to :controller => :elsewhere, :action => :flash_me; end

  def redirect_to_path() redirect_to '/some/path' end

  def redirect_invalid_external_route() redirect_to 'ht_tp://www.rubyonrails.org' end

  def redirect_to_named_route() redirect_to route_one_url end

  def redirect_external() redirect_to "http://www.rubyonrails.org"; end

  def response404() head '404 AWOL' end

  def response500() head '500 Sorry' end

  def response599() head '599 Whoah!' end

  def flash_me
    flash['hello'] = 'my name is inigo montoya...'
    render :text => "Inconceivable!"
  end

  def flash_me_naked
    flash.clear
    render :text => "wow!"
  end

  def assign_this
    @howdy = "ho"
    render :inline => "Mr. Henke"
  end

  def render_based_on_parameters
    render :text => "Mr. #{params[:name]}"
  end

  def render_url
    render :text => "<div>#{url_for(:action => 'flash_me', :only_path => true)}</div>"
  end

  def render_text_with_custom_content_type
    render :text => "Hello!", :content_type => Mime::RSS
  end

  def render_with_layout
    @variable_for_layout = nil
    render "test/hello_world", :layout => "layouts/standard"
  end

  def session_stuffing
    session['xmas'] = 'turkey'
    render :text => "ho ho ho"
  end

  def raise_exception_on_get
    raise "get" if request.get?
    render :text => "request method: #{request.env['REQUEST_METHOD']}"
  end

  def raise_exception_on_post
    raise "post" if request.post?
    render :text => "request method: #{request.env['REQUEST_METHOD']}"
  end
end

# Used to test that assert_response includes the exception message
# in the failure message when an action raises and assert_response
# is expecting something other than an error.
class AssertResponseWithUnexpectedErrorController < ActionController::Base
  def index
    raise 'FAIL'
  end

  def show
    render :text => "Boom", :status => 500
  end
end

module Admin
  class InnerModuleController < ActionController::Base
    def index
      render :nothing => true
    end

    def redirect_to_index
      redirect_to admin_inner_module_path
    end

    def redirect_to_absolute_controller
      redirect_to :controller => '/content'
    end

    def redirect_to_fellow_controller
      redirect_to :controller => 'user'
    end

    def redirect_to_top_level_named_route
      redirect_to top_level_url(:id => "foo")
    end
  end
end

class ActionPackAssertionsControllerTest < ActionController::TestCase

  def test_assert_tag_and_url_for
    get :render_url
    assert_tag :content => "/action_pack_assertions/flash_me"
  end

  def test_get_request
    assert_raise(RuntimeError) { get :raise_exception_on_get }
    get :raise_exception_on_post
    assert_equal @response.body, 'request method: GET'
  end

  def test_post_request
    assert_raise(RuntimeError) { post :raise_exception_on_post }
    post :raise_exception_on_get
    assert_equal @response.body, 'request method: POST'
  end

  def test_get_post_request_switch
    post :raise_exception_on_get
    assert_equal @response.body, 'request method: POST'
    get :raise_exception_on_post
    assert_equal @response.body, 'request method: GET'
    post :raise_exception_on_get
    assert_equal @response.body, 'request method: POST'
    get :raise_exception_on_post
    assert_equal @response.body, 'request method: GET'
  end

  def test_redirect_to_named_route
    with_routing do |set|
      set.draw do
        match 'route_one', :to => 'action_pack_assertions#nothing', :as => :route_one
        match ':controller/:action'
      end
      set.install_helpers

      process :redirect_to_named_route
      assert_redirected_to 'http://test.host/route_one'
      assert_redirected_to route_one_url
    end
  end

  def test_string_constraint
    with_routing do |set|
      set.draw do
        match "photos", :to => 'action_pack_assertions#nothing', :constraints => {:subdomain => "admin"}
      end
    end
  end

  def test_assert_redirect_to_named_route_failure
    with_routing do |set|
      set.draw do
        match 'route_one', :to => 'action_pack_assertions#nothing', :as => :route_one
        match 'route_two', :to => 'action_pack_assertions#nothing', :id => 'two', :as => :route_two
        match ':controller/:action'
      end
      process :redirect_to_named_route
      assert_raise(ActiveSupport::TestCase::Assertion) do
        assert_redirected_to 'http://test.host/route_two'
      end
      assert_raise(ActiveSupport::TestCase::Assertion) do
        assert_redirected_to :controller => 'action_pack_assertions', :action => 'nothing', :id => 'two'
      end
      assert_raise(ActiveSupport::TestCase::Assertion) do
        assert_redirected_to route_two_url
      end
    end
  end

  def test_assert_redirect_to_nested_named_route
    @controller = Admin::InnerModuleController.new

    with_routing do |set|
      set.draw do
        match 'admin/inner_module', :to => 'admin/inner_module#index', :as => :admin_inner_module
        match ':controller/:action'
      end
      process :redirect_to_index
      # redirection is <{"action"=>"index", "controller"=>"admin/admin/inner_module"}>
      assert_redirected_to admin_inner_module_path
    end
  end

  def test_assert_redirected_to_top_level_named_route_from_nested_controller
    @controller = Admin::InnerModuleController.new

    with_routing do |set|
      set.draw do
        match '/action_pack_assertions/:id', :to => 'action_pack_assertions#index', :as => :top_level
        match ':controller/:action'
      end
      process :redirect_to_top_level_named_route
      # assert_redirected_to "http://test.host/action_pack_assertions/foo" would pass because of exact match early return
      assert_redirected_to "/action_pack_assertions/foo"
    end
  end

  def test_assert_redirected_to_top_level_named_route_with_same_controller_name_in_both_namespaces
    @controller = Admin::InnerModuleController.new

    with_routing do |set|
      set.draw do
        # this controller exists in the admin namespace as well which is the only difference from previous test
        match '/user/:id', :to => 'user#index', :as => :top_level
        match ':controller/:action'
      end
      process :redirect_to_top_level_named_route
      # assert_redirected_to top_level_url('foo') would pass because of exact match early return
      assert_redirected_to top_level_path('foo')
    end
  end

  def test_template_objects_exist
    process :assign_this
    assert !@controller.instance_variable_defined?(:"@hi")
    assert @controller.instance_variable_get(:"@howdy")
  end

  def test_template_objects_missing
    process :nothing
    assert !@controller.instance_variable_defined?(:@howdy)
  end

  def test_empty_flash
    process :flash_me_naked
    assert flash.empty?
  end

  def test_flash_exist
    process :flash_me
    assert flash.any?
    assert_present flash['hello']
  end

  def test_flash_does_not_exist
    process :nothing
    assert flash.empty?
  end

  def test_session_exist
    process :session_stuffing
    assert_equal session['xmas'], 'turkey'
  end

  def session_does_not_exist
    process :nothing
    assert session.empty?
  end

  def test_render_template_action
    process :nothing
    assert_template nil

    process :hello_world
    assert_template 'hello_world'
  end

  def test_redirection_location
    process :redirect_internal
    assert_equal 'http://test.host/nothing', @response.redirect_url

    process :redirect_external
    assert_equal 'http://www.rubyonrails.org', @response.redirect_url
  end

  def test_no_redirect_url
    process :nothing
    assert_nil @response.redirect_url
  end

  def test_server_error_response_code
    process :response500
    assert @response.server_error?

    process :response599
    assert @response.server_error?

    process :response404
    assert !@response.server_error?
  end

  def test_missing_response_code
    process :response404
    assert @response.missing?
  end

  def test_client_error_response_code
    process :response404
    assert @response.client_error?
  end

  def test_redirect_url_match
    process :redirect_external
    assert @response.redirect?
    assert_match(/rubyonrails/, @response.redirect_url)
    assert !/perloffrails/.match(@response.redirect_url)
  end

  def test_redirection
    process :redirect_internal
    assert @response.redirect?

    process :redirect_external
    assert @response.redirect?

    process :nothing
    assert !@response.redirect?
  end

  def test_successful_response_code
    process :nothing
    assert @response.success?
  end

  def test_response_object
    process :nothing
    assert_kind_of ActionController::TestResponse, @response
  end

  def test_render_based_on_parameters
    process :render_based_on_parameters, "name" => "David"
    assert_equal "Mr. David", @response.body
  end

  def test_assert_redirection_fails_with_incorrect_controller
    process :redirect_to_controller
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_redirected_to :controller => "action_pack_assertions", :action => "flash_me"
    end
  end

  def test_assert_redirection_with_extra_controller_option
    get :redirect_to_action
    assert_redirected_to :controller => 'action_pack_assertions', :action => "flash_me", :id => 1, :params => { :panda => 'fun' }
  end

  def test_redirected_to_url_leading_slash
    process :redirect_to_path
    assert_redirected_to '/some/path'
  end

  def test_redirected_to_url_no_leading_slash_fails
    process :redirect_to_path
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_redirected_to 'some/path'
    end
  end

  def test_redirect_invalid_external_route
    process :redirect_invalid_external_route
    assert_redirected_to "http://test.hostht_tp://www.rubyonrails.org"
  end

  def test_redirected_to_url_full_url
    process :redirect_to_path
    assert_redirected_to 'http://test.host/some/path'
  end

  def test_assert_redirection_with_symbol
    process :redirect_to_controller_with_symbol
    assert_nothing_raised {
      assert_redirected_to :controller => "elsewhere", :action => "flash_me"
    }
    process :redirect_to_controller_with_symbol
    assert_nothing_raised {
      assert_redirected_to :controller => :elsewhere, :action => :flash_me
    }
  end

  def test_redirected_to_with_nested_controller
    @controller = Admin::InnerModuleController.new
    get :redirect_to_absolute_controller
    assert_redirected_to :controller => '/content'

    get :redirect_to_fellow_controller
    assert_redirected_to :controller => 'admin/user'
  end

  def test_assert_response_uses_exception_message
    @controller = AssertResponseWithUnexpectedErrorController.new
    get :index
    assert_response :success
    flunk 'Expected non-success response'
  rescue RuntimeError => e
    assert e.message.include?('FAIL')
  end

  def test_assert_response_failure_response_with_no_exception
    @controller = AssertResponseWithUnexpectedErrorController.new
    get :show
    assert_response :success
    flunk 'Expected non-success response'
  rescue ActiveSupport::TestCase::Assertion
    # success
  rescue
    flunk "assert_response failed to handle failure response with missing, but optional, exception."
  end
end

class AssertTemplateTest < ActionController::TestCase
  tests ActionPackAssertionsController

  def test_with_partial
    get :partial
    assert_template :partial => '_partial'
  end

  def test_with_nil_passes_when_no_template_rendered
    get :nothing
    assert_template nil
  end

  def test_with_nil_fails_when_template_rendered
    get :hello_world
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template nil
    end
  end

  def test_passes_with_correct_string
    get :hello_world
    assert_template 'hello_world'
    assert_template 'test/hello_world'
  end

  def test_passes_with_correct_symbol
    get :hello_world
    assert_template :hello_world
  end

  def test_fails_with_incorrect_string
    get :hello_world
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template 'hello_planet'
    end
  end

  def test_fails_with_incorrect_string_that_matches
    get :hello_world
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template 'est/he'
    end
  end

  def test_fails_with_repeated_name_in_path
    get :hello_repeating_in_path
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template 'test/hello'
    end
  end

  def test_fails_with_incorrect_symbol
    get :hello_world
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template :hello_planet
    end
  end

  def test_fails_with_incorrect_symbol_that_matches
    get :hello_world
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template :"est/he"
    end
  end

  def test_fails_with_wrong_layout
    get :render_with_layout
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_template :layout => "application"
    end
  end

  def test_passes_with_correct_layout
    get :render_with_layout
    assert_template :layout => "layouts/standard"
  end

  def test_assert_template_reset_between_requests
    get :hello_world
    assert_template 'test/hello_world'

    get :nothing
    assert_template nil
  end
end

class ActionPackHeaderTest < ActionController::TestCase
  tests ActionPackAssertionsController

  def test_rendering_xml_sets_content_type
    process :hello_xml_world
    assert_equal('application/xml; charset=utf-8', @response.headers['Content-Type'])
  end

  def test_rendering_xml_respects_content_type
    process :hello_xml_world_pdf
    assert_equal('application/pdf; charset=utf-8', @response.headers['Content-Type'])
  end

  def test_rendering_xml_respects_content_type_when_set_in_the_header
    process :hello_xml_world_pdf_header
    assert_equal('application/pdf; charset=utf-8', @response.headers['Content-Type'])
  end

  def test_render_text_with_custom_content_type
    get :render_text_with_custom_content_type
    assert_equal 'application/rss+xml; charset=utf-8', @response.headers['Content-Type']
  end
end
