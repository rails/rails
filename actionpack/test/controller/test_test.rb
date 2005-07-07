require File.dirname(__FILE__) + '/../abstract_unit'

class TestTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["test"] = ">#{flash["test"]}<"
    end
    
    def test_params
      render :text => params.inspect
    end                         
    
    def test_uri
      render :text => request.request_uri
    end

    def test_html_output
      render :text => <<HTML
<html>
  <body>
    <div id="foo">
      <ul>
        <li class="item">hello</li>
        <li class="item">goodbye</li>
      </ul>
    </div>
    <div id="bar">
      <form action="/somewhere">
        Name: <input type="text" name="person[name]" id="person_name" />
      </form>
    </div>
  </body>
</html>
HTML
    end
    
    def test_only_one_param
      render :text => (@params[:left] && @params[:right]) ? "EEP, Both here!" : "OK"
    end
  end

  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    ActionController::Routing::Routes.reload
  end

  def teardown
    ActionController::Routing::Routes.reload
  end

  def test_process_without_flash
    process :set_flash
    assert_flash_equal "><", "test"
  end          
  
  def test_process_with_flash
    process :set_flash, nil, nil, { "test" => "value" }
    assert_flash_equal ">value<", "test"
  end

  def test_process_with_request_uri_with_no_params
    process :test_uri
    assert_equal "/test_test/test/test_uri", @response.body
  end

  def test_process_with_request_uri_with_params
    process :test_uri, :id => 7
    assert_equal "/test_test/test/test_uri/7", @response.body
  end

  def test_process_with_request_uri_with_params_with_explicit_uri
    @request.set_REQUEST_URI "/explicit/uri"
    process :test_uri, :id => 7
    assert_equal "/explicit/uri", @response.body
  end                     
  
  def test_multiple_calls         
    process :test_only_one_param, :left => true
    assert_equal "OK", @response.body
    process :test_only_one_param, :right => true  
    assert_equal "OK", @response.body
  end

  def test_assert_tag
    process :test_html_output

    # there is a 'div', id='bar', with an immediate child whose 'action'
    # attribute matches the regexp /somewhere/.
    assert_tag :tag => "div", :attributes => { :id => "bar" },
               :child => { :attributes => { :action => /somewhere/ } }

    # there is no 'div', id='foo', with a 'ul' child with more than
    # 2 "li" children.
    assert_no_tag :tag => "div", :attributes => { :id => "foo" },
                  :child => {
                    :tag => "ul",
                    :children => { :greater_than => 2,
                                   :only => { :tag => "li" } } }
  end

  def test_assert_routing
    assert_generates 'controller/action/5', :controller => 'controller', :action => 'action', :id => '5'
  end

  def test_params_passing
    get :test_params, :page => {:name => "Page name", :month => '4', :year => '2004', :day => '6'}
    parsed_params = eval(@response.body)
    assert_equal(
      {'controller' => 'test_test/test', 'action' => 'test_params',
       'page' => {'name' => "Page name", 'month' => '4', 'year' => '2004', 'day' => '6'}},
      parsed_params
    )
  end

  def test_id_converted_to_string
    get :test_params, :id => 20, :foo => Object.new
    assert_kind_of String, @request.path_parameters['id']
  end

  def test_array_path_parameter_handled_properly
    with_routing do |set|
      set.draw do 
        set.connect 'file/*path', :controller => 'test_test/test', :action => 'test_params'
        set.connect ':controller/:action/:id'
      end
      
      get :test_params, :path => ['hello', 'world']
      assert_equal ['hello', 'world'], @request.path_parameters['path']
      assert_equal 'hello/world', @request.path_parameters['path'].to_s
    end
  end

  def test_assert_realistic_path_parameters
    get :test_params, :id => 20, :foo => Object.new

    # All elements of path_parameters should use string keys
    @request.path_parameters.keys.each do |key|
      assert_kind_of String, key
    end
  end

  def test_with_routing_places_routes_back
    assert ActionController::Routing::Routes
    routes_id = ActionController::Routing::Routes.object_id
    
    begin
      with_routing { raise 'fail' }
      fail 'Should not be here.'
    rescue RuntimeError
    end
    
    assert ActionController::Routing::Routes
    assert_equal routes_id, ActionController::Routing::Routes.object_id
  end
end
