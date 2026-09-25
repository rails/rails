# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"
require "action_view/template/types"

class ActionView::Template::SimpleTypeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  test "the symbols list is shareable" do
    assert_ractor_shareable ActionView::Template::SimpleType.symbols
  end

  test "instances are shareable" do
    assert_ractor_shareable ActionView::Template::SimpleType[:html]
  end
end
