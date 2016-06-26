require 'abstract_unit'

class FormWithHelperTest < ActionView::TestCase

  tests ActionView::Helpers::FormTagHelper

  def test_form_tag
    assert_dom_equal "<form></form>", form_with
  end

end