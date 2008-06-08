require 'abstract_unit'

class DeprecatedErbVariableTest < ActionView::TestCase
  def test_setting_erb_variable_warns
    assert_deprecated 'erb_variable' do
      ActionView::Base.erb_variable = '_erbout'
    end
  end
end
