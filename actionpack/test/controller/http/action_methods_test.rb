require 'abstract_unit'

class ActionMethodsHTTPController < ActionController::HTTP
  def one; end
  def two; end
  hide_action :two
end

class ActionMethodsHTTPTest < ActiveSupport::TestCase
  def setup
    @controller = ActionMethodsHTTPController.new
  end

  def test_action_methods
    assert_equal Set.new(%w(one)),
                 @controller.class.action_methods,
                 "#{@controller.controller_path} should not be empty!"
  end
end
