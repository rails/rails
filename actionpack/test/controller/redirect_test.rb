require File.dirname(__FILE__) + '/../abstract_unit'

class RedirectController < ActionController::Base
  def simple_redirect
    redirect_to :action => "hello_world"
  end
  
  def method_redirect
    redirect_to :dashbord_url, 1, "hello"
  end
  
  def host_redirect
    redirect_to :action => "other_host", :only_path => false, :host => 'other.test.host'
  end

  def module_redirect
    redirect_to :controller => 'module_test/module_redirect', :action => "hello_world"
  end

  def redirect_with_assigns
    @hello = "world"
    redirect_to :action => "hello_world"
  end

  def redirect_to_back
    redirect_to :back
  end

  def rescue_errors(e) raise e end
  
  protected
    def dashbord_url(id, message)
      url_for :action => "dashboard", :params => { "id" => id, "message" => message }
    end
end

class RedirectTest < Test::Unit::TestCase
  def setup
    @controller = RedirectController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_simple_redirect
    get :simple_redirect
    assert_redirect_url "http://test.host/redirect/hello_world"
  end

  def test_redirect_with_method_reference_and_parameters
    get :method_redirect
    assert_redirect_url "http://test.host/redirect/dashboard/1?message=hello"
  end

  def test_simple_redirect_using_options
    get :host_redirect
    assert_redirected_to :action => "other_host", :only_path => false, :host => 'other.test.host'
  end

  def test_module_redirect
    get :module_redirect
    assert_redirect_url "http://test.host/module_test/module_redirect/hello_world"
  end

  def test_module_redirect_using_options
    get :module_redirect
    assert_redirected_to :controller => 'module_test/module_redirect', :action => 'hello_world'
  end

  def test_redirect_with_assigns
    get :redirect_with_assigns
    assert_equal "world", assigns["hello"]
  end

  def test_redirect_to_back
    @request.env["HTTP_REFERER"] = "http://www.example.com/coming/from"
    get :redirect_to_back
    assert_redirect_url "http://www.example.com/coming/from"
  end
end

module ModuleTest
  class ModuleRedirectController < ::RedirectController
    def module_redirect
      redirect_to :controller => '/redirect', :action => "hello_world"
    end
  end

  class ModuleRedirectTest < Test::Unit::TestCase
    def setup
      @controller = ModuleRedirectController.new
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new
    end
  
    def test_simple_redirect
      get :simple_redirect
      assert_redirect_url "http://test.host/module_test/module_redirect/hello_world"
    end
  
    def test_redirect_with_method_reference_and_parameters
      get :method_redirect
      assert_redirect_url "http://test.host/module_test/module_redirect/dashboard/1?message=hello"
    end
    
    def test_simple_redirect_using_options
      get :host_redirect
      assert_redirected_to :action => "other_host", :only_path => false, :host => 'other.test.host'
    end

    def test_module_redirect
      get :module_redirect
      assert_redirect_url "http://test.host/redirect/hello_world"
    end

    def test_module_redirect_using_options
      get :module_redirect
      assert_redirected_to :controller => 'redirect', :action => "hello_world"
    end
  end
end
