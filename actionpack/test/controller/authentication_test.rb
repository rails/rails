require File.dirname(__FILE__) + '/../abstract_unit'

class AuthenticationTest < Test::Unit::TestCase
  class ApplicationController < ActionController::Base
    authentication :by => '@session[:authenticated]', :before => '@session[:return_to] = "/weblog/"', :failure => { :controller => "login" }
  end

  class WeblogController < ApplicationController
    def show()   render_text "I showed something"  end
    def index()  render_text "I indexed something" end
    def edit()   render_text "I edited something"  end
    def update() render_text "I updated something" end
    def login
      @session[:authenticated] = true
      @session[:return_to] ? redirect_to_path(@session[:return_to]) : render_nothing
    end
  end

  class AuthenticatesWeblogController < WeblogController
    authenticates :edit, :update
  end

  class AuthenticatesAllWeblogController < WeblogController
    authenticates_all
  end

  class AuthenticatesAllExceptWeblogController < WeblogController
    authenticates_all_except :show, :index, :login
  end

  class AuthenticatesSomeController < AuthenticatesAllWeblogController
    authenticates_all_except :show
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_access_on_authenticates
    @controller = AuthenticatesWeblogController.new

    get :show
    assert_success

    get :edit
    assert_redirected_to :controller => "login"
  end

  def test_access_on_authenticates_all
    @controller = AuthenticatesAllWeblogController.new

    get :show
    assert_redirected_to :controller => "login"

    get :edit
    assert_redirected_to :controller => "login"
  end

  def test_access_on_authenticates_all_except
    @controller = AuthenticatesAllExceptWeblogController.new

    get :show
    assert_success

    get :edit
    assert_redirected_to :controller => "login"
  end
  
  def test_access_on_authenticates_some
    @controller = AuthenticatesSomeController.new

    get :show
    assert_success

    get :edit
    assert_redirected_to :controller => "login"
  end
  
  def test_authenticated_access_on_authenticates
    @controller = AuthenticatesWeblogController.new

    get :login
    assert_success

    get :show
    assert_success

    get :edit
    assert_success
  end
  
  def test_before_condition
    @controller = AuthenticatesWeblogController.new

    get :edit
    assert_redirected_to :controller => "login"
    
    get :login
    assert_redirect_url "http://test.host/weblog/"
  end
end