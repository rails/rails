require 'abstract_unit'

# class TranslatingController < ActionController::Base
# end

class TranslationControllerTest < ActiveSupport::TestCase
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

  def test_lazy_lookup
    expected = 'bar'
    @controller.stubs(:action_name => :index)
    I18n.stubs(:translate).with('action_controller.base.index.foo').returns(expected)
    assert_equal expected, @controller.t('.foo')
  end

  def test_default_translation
    key, expected = 'one.two' 'bar'
    I18n.stubs(:translate).with(key).returns(expected)
    assert_equal expected, @controller.t(key)
  end
end
