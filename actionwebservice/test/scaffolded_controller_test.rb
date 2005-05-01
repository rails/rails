require File.dirname(__FILE__) + '/abstract_unit'

ActionController::Routing::Routes.draw do |map|
  map.connect '', :controller => 'scaffolded'
end

class ScaffoldPerson < ActionWebService::Struct
  member :id,   :int
  member :name, :string

  def ==(other)
    self.id == other.id && self.name == other.name
  end
end

class ScaffoldedControllerTestAPI < ActionWebService::API::Base
  api_method :hello, :expects => [{:integer=>:int}, :string], :returns => [:bool]
  api_method :bye,   :returns => [[ScaffoldPerson]]
end

class ScaffoldedController < ActionController::Base
  web_service_api ScaffoldedControllerTestAPI
  web_service_scaffold :scaffold_invoke

  def hello(int, string)
    0
  end

  def bye
    [ScaffoldPerson.new(:id => 1, :name => "leon"), ScaffoldPerson.new(:id => 2, :name => "paul")]
  end

  def rescue_action(e)
    raise e
  end
end

class ScaffoldedControllerTest < Test::Unit::TestCase
  def setup
    @controller = ScaffoldedController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_scaffold_invoke
    get :scaffold_invoke
    assert_rendered_file 'methods.rhtml'
  end

  def test_scaffold_invoke_method_params
    get :scaffold_invoke_method_params, :service => 'scaffolded', :method => 'Hello'
    assert_rendered_file 'parameters.rhtml'
  end

  def test_scaffold_invoke_submit_hello
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'Hello', :method_params => {'0' => '5', '1' => 'hello world'}
    assert_rendered_file 'result.rhtml'
    assert_equal false, @controller.instance_eval{ @method_return_value }
  end

  def test_scaffold_invoke_submit_bye
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'Bye'
    assert_rendered_file 'result.rhtml'
    persons = [ScaffoldPerson.new(:id => 1, :name => "leon"), ScaffoldPerson.new(:id => 2, :name => "paul")]
    assert_equal persons, @controller.instance_eval{ @method_return_value }
  end
end
