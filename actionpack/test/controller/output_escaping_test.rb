require 'abstract_unit'

class OutputEscapingTest < ActiveSupport::TestCase

  test "escape_html shouldn't die when passed nil" do
    assert ERB::Util.h(nil).blank?
  end

  test "escapeHTML should escape strings" do
    assert_equal "&lt;&gt;&quot;", ERB::Util.h("<>\"")
  end

  test "escapeHTML shouldn't touch explicitly safe strings" do
    # TODO this seems easier to compose and reason about, but
    # this should be verified
    assert_equal "<", ERB::Util.h("<".html_safe)
  end

end
