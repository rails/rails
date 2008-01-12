require File.dirname(__FILE__) + '/../abstract_unit'

class WorkshopsController < ActionController::Base
end

class Workshop
  attr_accessor :id, :new_record

  def initialize(id, new_record)
    @id, @new_record = id, new_record
  end
  
  def new_record?
    @new_record
  end
  
  def to_s
    id.to_s
  end
end

class RedirectController < ActionController::Base
  def simple_redirect
    redirect_to :action => "hello_world"
  end

  def redirect_with_status 
    redirect_to({:action => "hello_world", :status => 301})
  end 

  def redirect_with_status_hash
    redirect_to({:action => "hello_world"}, {:status => 301})
  end 

  def url_redirect_with_status 
    redirect_to("http://www.example.com", :status => :moved_permanently)
  end 
   
  def url_redirect_with_status_hash 
    redirect_to("http://www.example.com", {:status => 301})
  end 

  def relative_url_redirect_with_status 
    redirect_to("/things/stuff", :status => :found)
  end 
   
  def relative_url_redirect_with_status_hash
    redirect_to("/things/stuff", {:status => 301})
  end 
   
  def redirect_to_back_with_status 
    redirect_to :back, :status => 307 
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

  def redirect_to_existing_record
    redirect_to Workshop.new(5, false)
  end

  def redirect_to_new_record
    redirect_to Workshop.new(5, true)
  end

  def redirect_to_nil
    redirect_to nil
  end

  def rescue_errors(e) raise e end
    
  def rescue_action(e) raise end
  
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
    assert_response :redirect
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url
  end

  def test_redirect_with_no_status
    get :simple_redirect
    assert_response 302
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url
  end

  def test_redirect_with_status 
    get :redirect_with_status 
    assert_response 301 
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url 
  end 

  def test_redirect_with_status_hash 
    get :redirect_with_status_hash
    assert_response 301 
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url 
  end
   
  def test_url_redirect_with_status 
    get :url_redirect_with_status 
    assert_response 301 
    assert_equal "http://www.example.com", redirect_to_url 
  end 

  def test_url_redirect_with_status_hash
    get :url_redirect_with_status_hash
    assert_response 301 
    assert_equal "http://www.example.com", redirect_to_url 
  end 

  
  def test_relative_url_redirect_with_status 
    get :relative_url_redirect_with_status 
    assert_response 302
    assert_equal "http://test.host/things/stuff", redirect_to_url 
  end 
   
  def test_relative_url_redirect_with_status_hash
    get :relative_url_redirect_with_status_hash
    assert_response 301 
    assert_equal "http://test.host/things/stuff", redirect_to_url 
  end   
   
  def test_redirect_to_back_with_status 
    @request.env["HTTP_REFERER"] = "http://www.example.com/coming/from" 
    get :redirect_to_back_with_status 
    assert_response 307 
    assert_equal "http://www.example.com/coming/from", redirect_to_url 
  end

  def test_simple_redirect_using_options
    get :host_redirect
    assert_response :redirect
    assert_redirected_to :action => "other_host", :only_path => false, :host => 'other.test.host'
  end

  def test_redirect_error_with_pretty_diff
    get :host_redirect
    assert_response :redirect
    begin
      assert_redirected_to :action => "other_host", :only_path => true
    rescue Test::Unit::AssertionFailedError => err
      expected_msg, redirection_msg, diff_msg = err.message.scan(/<\{[^\}]+\}>/).collect { |s| s[2..-3] }
      assert_match %r("only_path"=>false),        redirection_msg
      assert_match %r("host"=>"other.test.host"), redirection_msg
      assert_match %r("action"=>"other_host"),    redirection_msg
      assert_match %r("only_path"=>false),        diff_msg
      assert_match %r("host"=>"other.test.host"), diff_msg
    end
  end

  def test_module_redirect
    get :module_redirect
    assert_response :redirect
    assert_redirected_to "http://test.host/module_test/module_redirect/hello_world"
  end

  def test_module_redirect_using_options
    get :module_redirect
    assert_response :redirect
    assert_redirected_to :controller => 'module_test/module_redirect', :action => 'hello_world'
  end

  def test_redirect_with_assigns
    get :redirect_with_assigns
    assert_response :redirect
    assert_equal "world", assigns["hello"]
  end

  def test_redirect_to_back
    @request.env["HTTP_REFERER"] = "http://www.example.com/coming/from"
    get :redirect_to_back
    assert_response :redirect
    assert_equal "http://www.example.com/coming/from", redirect_to_url
  end
  
  def test_redirect_to_back_with_no_referer
    assert_raises(ActionController::RedirectBackError) {
      @request.env["HTTP_REFERER"] = nil
      get :redirect_to_back
    }
  end
  
  def test_redirect_to_record
    ActionController::Routing::Routes.draw do |map|
      map.resources :workshops
      map.connect ':controller/:action/:id'
    end
    
    get :redirect_to_existing_record
    assert_equal "http://test.host/workshops/5", redirect_to_url

    get :redirect_to_new_record
    assert_equal "http://test.host/workshops", redirect_to_url
  end

  def test_redirect_to_nil
    assert_raises(ActionController::ActionControllerError) do
      get :redirect_to_nil
    end
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
      assert_response :redirect
      assert_equal "http://test.host/module_test/module_redirect/hello_world", redirect_to_url
    end

    def test_simple_redirect_using_options
      get :host_redirect
      assert_response :redirect
      assert_redirected_to :action => "other_host", :only_path => false, :host => 'other.test.host'
    end

    def test_module_redirect
      get :module_redirect
      assert_response :redirect
      assert_equal "http://test.host/redirect/hello_world", redirect_to_url
    end

    def test_module_redirect_using_options
      get :module_redirect
      assert_response :redirect
      assert_redirected_to :controller => 'redirect', :action => "hello_world"
    end
  end
end
