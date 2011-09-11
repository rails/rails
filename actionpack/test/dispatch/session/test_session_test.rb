require 'abstract_unit'
require 'stringio'

class ActionController::TestSessionTest < ActiveSupport::TestCase
  def test_ctor_allows_setting
    session = ActionController::TestSession.new({:one => 'one', :two => 'two'})
    assert_equal('one', session[:one])
    assert_equal('two', session[:two])
  end

  def test_setting_session_item_sets_item
    session = ActionController::TestSession.new
    session[:key] = 'value'
    assert_equal('value', session[:key])
  end

  def test_calling_delete_removes_item_and_returns_its_value
    session = ActionController::TestSession.new
    session[:key] = 'value'
    assert_equal('value', session[:key])
    assert_equal('value', session.delete(:key))
    assert_nil(session[:key])
  end

  def test_calling_update_with_params_passes_to_attributes
    session = ActionController::TestSession.new()
    session.update('key' => 'value')
    assert_equal('value', session[:key])
  end

  def test_clear_emptys_session
    session = ActionController::TestSession.new({:one => 'one', :two => 'two'})
    session.clear
    assert_nil(session[:one])
    assert_nil(session[:two])
  end
end
