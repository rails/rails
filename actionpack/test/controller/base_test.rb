require File.dirname(__FILE__) + '/../abstract_unit'
require 'test/unit'
require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

# Provide some controller to run the tests on.
module Submodule
  class ContainedEmptyController < ActionController::Base
  end
  class ContainedNonEmptyController < ActionController::Base
    def public_action
    end
    
    hide_action :hidden_action
    def hidden_action
      raise "Noooo!"
    end
    
    def another_hidden_action
    end
    hide_action :another_hidden_action
  end
  class SubclassedController < ContainedNonEmptyController
    hide_action :public_action # Hiding it here should not affect the superclass.
  end
end
class EmptyController < ActionController::Base
end
class NonEmptyController < ActionController::Base
  def public_action
  end
  
  hide_action :hidden_action
  def hidden_action
  end
end

class MethodMissingController < ActionController::Base
  
  hide_action :shouldnt_be_called
  def shouldnt_be_called
    raise "NO WAY!"
  end
  
protected
  
  def method_missing(selector)
    render :text => selector.to_s
  end
  
end

class ControllerClassTests < Test::Unit::TestCase
  def test_controller_path
    assert_equal 'empty', EmptyController.controller_path
    assert_equal EmptyController.controller_path, EmptyController.new.controller_path
    assert_equal 'submodule/contained_empty', Submodule::ContainedEmptyController.controller_path
    assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
  end
  def test_controller_name
    assert_equal 'empty', EmptyController.controller_name
    assert_equal 'contained_empty', Submodule::ContainedEmptyController.controller_name
 end
end

class ControllerInstanceTests < Test::Unit::TestCase
  def setup
    @empty = EmptyController.new
    @contained = Submodule::ContainedEmptyController.new
    @empty_controllers = [@empty, @contained, Submodule::SubclassedController.new]
    
    @non_empty_controllers = [NonEmptyController.new,
                              Submodule::ContainedNonEmptyController.new]
  end

  def test_action_methods
    @empty_controllers.each do |c|
      hide_mocha_methods_from_controller(c)
      assert_equal Set.new, c.send!(:action_methods), "#{c.controller_path} should be empty!"
    end
    @non_empty_controllers.each do |c|
      hide_mocha_methods_from_controller(c)
      assert_equal Set.new(%w(public_action)), c.send!(:action_methods), "#{c.controller_path} should not be empty!"
    end
  end

  protected
    # Mocha adds some public instance methods to Object that would be
    # considered actions, so explicitly hide_action them.
    def hide_mocha_methods_from_controller(controller)
      mocha_methods = [
        :expects, :mocha, :mocha_inspect, :reset_mocha, :stubba_object,
        :stubba_method, :stubs, :verify, :__metaclass__, :__is_a__, :to_matcher,
      ]
      controller.class.send!(:hide_action, *mocha_methods)
    end
end


class PerformActionTest < Test::Unit::TestCase
  def use_controller(controller_class)
    @controller = controller_class.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end
  
  def test_get_on_priv_should_show_selector
    use_controller MethodMissingController
    get :shouldnt_be_called
    assert_response :success
    assert_equal 'shouldnt_be_called', @response.body
  end
  
  def test_method_missing_is_not_an_action_name
    use_controller MethodMissingController
    assert ! @controller.send!(:action_methods).include?('method_missing')
    
    get :method_missing
    assert_response :success
    assert_equal 'method_missing', @response.body
  end
  
  def test_get_on_hidden_should_fail
    use_controller NonEmptyController
    get :hidden_action
    assert_response 404
    
    get :another_hidden_action
    assert_response 404
  end
end
