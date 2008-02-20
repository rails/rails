require File.dirname(__FILE__) + '/../active_record_unit'
require "action_controller/test_case"

class ActionController::TestCase
  self.fixture_path = File.dirname(__FILE__) + '/../fixtures'
  self.use_transactional_fixtures = false
end

class DeveloperController < ActionController::Base
end

class DeveloperControllerTest < ActionController::TestCase
  fixtures :developers

  def setup
    @david = developers(:david)
  end

  def test_should_have_loaded_fixtures
    assert_kind_of(Developer, @david)
    assert_kind_of(Developer, developers(:jamis))
    assert_equal(@developers.size, Developer.count)
  end
end
