require File.dirname(__FILE__) + '/../abstract_unit'

class ViewLoadPathsTest < Test::Unit::TestCase
  
  LOAD_PATH_ROOT = File.join(File.dirname(__FILE__), '..', 'fixtures')

  class TestController < ActionController::Base
    def self.controller_path() "test" end
    def rescue_action(e) raise end
      
    def hello_world() end
  end
  
  def setup
    TestController.view_paths = [ LOAD_PATH_ROOT ]
    @controller = TestController.new
    @request  = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  
    # Track the last warning.
    @old_behavior = ActiveSupport::Deprecation.behavior
    @last_message = nil
    ActiveSupport::Deprecation.behavior = Proc.new { |message| @last_message = message }
  end
  
  def teardown
    ActiveSupport::Deprecation.behavior = @old_behavior
  end
  
  def test_template_load_path_was_set_correctly
    assert_equal [ LOAD_PATH_ROOT ], @controller.view_paths
  end
  
  def test_view_paths
    get :hello_world
    assert_response :success
    assert_equal "Hello world!", @response.body
  end
  
  def test_view_paths_override
    TestController.view_paths.unshift "#{LOAD_PATH_ROOT}/override"
    get :hello_world
    assert_response :success
    assert_equal "Hello overridden world!", @response.body
  end
  
  def test_template_root_deprecated
    assert_deprecated(/template_root.*view_paths/) do
      TestController.template_root = 'foo/bar'
    end
    assert_deprecated(/template_root.*view_paths/) do
      assert_equal 'foo/bar', TestController.template_root
      assert_equal ['foo/bar', LOAD_PATH_ROOT], TestController.view_paths
    end
  end
  
  def test_inheritance
    original_load_paths = ActionController::Base.view_paths
    
    self.class.class_eval %{
      class A < ActionController::Base; end
      class B < A; end
      class C < ActionController::Base; end
    }
  
    A.view_paths = [ 'a/path' ]
    
    assert_equal [ 'a/path' ],        A.view_paths
    assert_equal A.view_paths,   B.view_paths
    assert_equal original_load_paths, C.view_paths
    
    e = assert_raises(TypeError) { C.view_paths << 'c/path' }
    assert_equal "can't modify frozen array", e.message
    
    C.view_paths = []
    assert_nothing_raised { C.view_paths << 'c/path' }
  end
  
end