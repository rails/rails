require File.dirname(__FILE__) + '/abstract_unit'

ActionController::Routing::Routes.draw do |map|
  map.connect '', :controller => 'scaffolded'
  map.connect ':controller/:action/:id'
end

ActionController::Base.view_load_paths = [ '.' ]

class ScaffoldPerson < ActionWebService::Struct
  member :id,     :int
  member :name,   :string
  member :birth,  :date

  def ==(other)
    self.id == other.id && self.name == other.name
  end
end

class ScaffoldedControllerTestAPI < ActionWebService::API::Base
  api_method :hello, :expects => [{:integer=>:int}, :string], :returns => [:bool]
  api_method :hello_struct_param, :expects => [{:person => ScaffoldPerson}], :returns => [:bool]
  api_method :date_of_birth, :expects => [ScaffoldPerson], :returns => [:string]
  api_method :bye,   :returns => [[ScaffoldPerson]]
  api_method :date_diff, :expects => [{:start_date => :date}, {:end_date => :date}], :returns => [:int]
  api_method :time_diff, :expects => [{:start_time => :time}, {:end_time => :time}], :returns => [:int]
  api_method :base64_upcase, :expects => [:base64], :returns => [:base64]
end

class ScaffoldedController < ActionController::Base
  web_service_api ScaffoldedControllerTestAPI
  web_service_scaffold :scaffold_invoke

  def hello(int, string)
    0
  end
  
  def hello_struct_param(person)
    0
  end
  
  def date_of_birth(person)
    person.birth.to_s
  end

  def bye
    [ScaffoldPerson.new(:id => 1, :name => "leon"), ScaffoldPerson.new(:id => 2, :name => "paul")]
  end

  def rescue_action(e)
    raise e
  end
  
  def date_diff(start_date, end_date)
    end_date - start_date
  end
  
  def time_diff(start_time, end_time)
    end_time - start_time
  end
  
  def base64_upcase(data)
    data.upcase
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
    assert_template 'methods.erb'
  end

  def test_scaffold_invoke_method_params
    get :scaffold_invoke_method_params, :service => 'scaffolded', :method => 'Hello'
    assert_template 'parameters.erb'
  end
  
  def test_scaffold_invoke_method_params_with_struct
    get :scaffold_invoke_method_params, :service => 'scaffolded', :method => 'HelloStructParam'
    assert_template 'parameters.erb'
    assert_tag :tag => 'form'
    assert_tag :tag => 'input', :attributes => {:name => "method_params[0][name]"}
  end

  def test_scaffold_invoke_submit_hello
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'Hello', :method_params => {'0' => '5', '1' => 'hello world'}
    assert_template 'result.erb'
    assert_equal false, @controller.instance_eval{ @method_return_value }
  end

  def test_scaffold_invoke_submit_bye
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'Bye'
    assert_template 'result.erb'
    persons = [ScaffoldPerson.new(:id => 1, :name => "leon"), ScaffoldPerson.new(:id => 2, :name => "paul")]
    assert_equal persons, @controller.instance_eval{ @method_return_value }
  end
  
  def test_scaffold_date_params
    get :scaffold_invoke_method_params, :service => 'scaffolded', :method => 'DateDiff'
    (0..1).each do |param|
      (1..3).each do |date_part|
        assert_tag :tag => 'select', :attributes => {:name => "method_params[#{param}][#{date_part}]"}, 
                   :children => {:greater_than => 1, :only => {:tag => 'option'}}
      end
    end
    
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'DateDiff', 
         :method_params => {'0' => {'1' => '2006', '2' => '2', '3' => '1'}, '1' => {'1' => '2006', '2' => '2', '3' => '2'}}
    assert_equal 1, @controller.instance_eval{ @method_return_value }
  end
  
  def test_scaffold_struct_date_params
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'DateOfBirth', 
         :method_params => {'0' => {'birth' => {'1' => '2006', '2' => '2', '3' => '1'}, 'id' => '1', 'name' => 'person'}}
    assert_equal '2006-02-01', @controller.instance_eval{ @method_return_value }
  end

  def test_scaffold_time_params
    get :scaffold_invoke_method_params, :service => 'scaffolded', :method => 'TimeDiff'
    (0..1).each do |param|
      (1..6).each do |date_part|
        assert_tag :tag => 'select', :attributes => {:name => "method_params[#{param}][#{date_part}]"}, 
                   :children => {:greater_than => 1, :only => {:tag => 'option'}}
      end
    end

    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'TimeDiff', 
         :method_params => {'0' => {'1' => '2006', '2' => '2', '3' => '1', '4' => '1', '5' => '1', '6' => '1'}, 
                            '1' => {'1' => '2006', '2' => '2', '3' => '2', '4' => '1', '5' => '1', '6' => '1'}}
    assert_equal 86400, @controller.instance_eval{ @method_return_value }
  end
  
  def test_scaffold_base64
    get :scaffold_invoke_method_params, :service => 'scaffolded', :method => 'Base64Upcase'
    assert_tag :tag => 'textarea', :attributes => {:name => 'method_params[0]'}
    
    post :scaffold_invoke_submit, :service => 'scaffolded', :method => 'Base64Upcase', :method_params => {'0' => 'scaffold'}
    assert_equal 'SCAFFOLD', @controller.instance_eval{ @method_return_value }
  end
end
