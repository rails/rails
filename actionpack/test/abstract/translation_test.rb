require 'abstract_unit'

# class TranslatingController < ActionController::Base
# end

class TranslationControllerTest < Test::Unit::TestCase
  def setup
    @controller = ActionController::Base.new
  end

  def test_action_controller_base_responds_to_translate
    assert_respond_to @controller, :translate
  end

  def test_action_controller_base_responds_to_t
    assert_respond_to @controller, :t
  end

  def test_action_controller_base_responds_to_localize
    assert_respond_to @controller, :localize
  end

  def test_action_controller_base_responds_to_l
    assert_respond_to @controller, :l
  end
end