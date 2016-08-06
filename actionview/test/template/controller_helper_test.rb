require "abstract_unit"

class ControllerHelperTest < ActionView::TestCase
  tests ActionView::Helpers::ControllerHelper

  class SpecializedFormBuilder < ActionView::Helpers::FormBuilder ; end

  def test_assign_controller_sets_default_form_builder
    @controller = OpenStruct.new(default_form_builder: SpecializedFormBuilder)
    assign_controller(@controller)

    assert_equal SpecializedFormBuilder, self.default_form_builder
  end

  def test_assign_controller_skips_default_form_builder
    @controller = OpenStruct.new
    assign_controller(@controller)

    assert_nil self.default_form_builder
  end
end
