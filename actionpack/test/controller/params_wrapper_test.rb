require 'abstract_unit'

module Admin; class User; end; end

class ParamsWrapperTest < ActionController::TestCase
  class UsersController < ActionController::Base
    def test
      render :json => params.except(:controller, :action)
    end
  end

  class User; end
  class Person; end

  tests UsersController

  def test_derivered_name_from_controller
    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu' }
      assert_equal '{"username":"sikachu","user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_specify_wrapper_name
    with_default_wrapper_options do
      UsersController.wrap_parameters :person

      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu' }
      assert_equal '{"username":"sikachu","person":{"username":"sikachu"}}', @response.body
    end
  end

  def test_specify_wrapper_model
    with_default_wrapper_options do
      UsersController.wrap_parameters Person

      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu' }
      assert_equal '{"username":"sikachu","person":{"username":"sikachu"}}', @response.body
    end
  end

  def test_specify_only_option
    with_default_wrapper_options do
      UsersController.wrap_parameters :only => :username

      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_specify_except_option
    with_default_wrapper_options do
      UsersController.wrap_parameters :except => :title

      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_specify_both_wrapper_name_and_only_option
    with_default_wrapper_options do
      UsersController.wrap_parameters :person, :only => :username

      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","person":{"username":"sikachu"}}', @response.body
    end
  end

  def test_not_enabled_format
    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/xml'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer"}', @response.body
    end
  end

  def test_wrap_parameters_false
    with_default_wrapper_options do
      UsersController.wrap_parameters false
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer"}', @response.body
    end
  end

  def test_specify_format
    with_default_wrapper_options do
      UsersController.wrap_parameters :format => :xml

      @request.env['CONTENT_TYPE'] = 'application/xml'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","user":{"username":"sikachu","title":"Developer"}}', @response.body
    end
  end

  def test_not_wrap_reserved_parameters
    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'authenticity_token' => 'pwned', '_method' => 'put', 'utf8' => '&#9731;', 'username' => 'sikachu' }
      assert_equal '{"authenticity_token":"pwned","_method":"put","utf8":"&#9731;","username":"sikachu","user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_no_double_wrap_if_key_exists
    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'user' => { 'username' => 'sikachu' }}
      assert_equal '{"user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_nested_params
    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'person' => { 'username' => 'sikachu' }}
      assert_equal '{"person":{"username":"sikachu"},"user":{"person":{"username":"sikachu"}}}', @response.body
    end
  end

  def test_derived_wrapped_keys_from_matching_model
    User.expects(:respond_to?).with(:column_names).returns(true)
    User.expects(:column_names).returns(["username"])

    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_derived_wrapped_keys_from_specified_model
    with_default_wrapper_options do
      Person.expects(:respond_to?).with(:column_names).returns(true)
      Person.expects(:column_names).returns(["username"])

      UsersController.wrap_parameters Person

      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","person":{"username":"sikachu"}}', @response.body
    end
  end

  private
    def with_default_wrapper_options(&block)
      @controller.class._wrapper_options = {:format => [:json]}
      @controller.class.inherited(@controller.class)
      yield
    end
end

class NamespacedParamsWrapperTest < ActionController::TestCase
  module Admin
    class UsersController < ActionController::Base
      def test
        render :json => params.except(:controller, :action)
      end
    end
  end

  class Sample
    def self.column_names
      ["username"]
    end
  end

  tests Admin::UsersController

  def test_derivered_name_from_controller
    with_default_wrapper_options do
      @request.env['CONTENT_TYPE'] = 'application/json'
      post :test, { 'username' => 'sikachu' }
      assert_equal '{"username":"sikachu","user":{"username":"sikachu"}}', @response.body
    end
  end

  def test_namespace_lookup_from_model
    Admin.const_set(:User, Class.new(Sample))
    begin
      with_default_wrapper_options do
        @request.env['CONTENT_TYPE'] = 'application/json'
        post :test, { 'username' => 'sikachu', 'title' => 'Developer' }
      assert_equal '{"username":"sikachu","title":"Developer","user":{"username":"sikachu"}}', @response.body
      end
    ensure
      Admin.send :remove_const, :User
    end
  end

  private
    def with_default_wrapper_options(&block)
      @controller.class._wrapper_options = {:format => [:json]}
      @controller.class.inherited(@controller.class)
      yield
    end
end
