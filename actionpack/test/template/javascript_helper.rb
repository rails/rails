require File.dirname(__FILE__) + '/../abstract_unit'

class JavascriptHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavascriptHelper

  def test_escape_javascript
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
  end
end
