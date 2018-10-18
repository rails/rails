# frozen_string_literal: true

require "abstract_unit"

class OutputEscapingTest < ActiveSupport::TestCase
  test "escape_html shouldn't die when passed nil" do
    assert_predicate ERB::Util.h(nil), :blank?
  end

  test "escapeHTML should escape strings" do
    assert_equal "&lt;&gt;&quot;", ERB::Util.h("<>\"")
  end

  test "escapeHTML shouldn't touch explicitly safe strings" do
    assert_equal "<", ERB::Util.h("<".html_safe)
  end
end
