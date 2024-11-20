# frozen_string_literal: true

require "abstract_unit"

class ControllerHelperTest < ActionView::TestCase
  tests ActionView::Helpers::ControllerHelper

  class SpecializedFormBuilder < ActionView::Helpers::FormBuilder ; end

  def test_assign_controller_sets_default_form_builder
    @controller = Struct.new(:default_form_builder).new(SpecializedFormBuilder)
    assign_controller(@controller)

    assert_equal SpecializedFormBuilder, default_form_builder
  end

  def test_assign_controller_skips_default_form_builder
    @controller = Object.new
    assign_controller(@controller)

    assert_nil default_form_builder
  end

  def test_respond_to
    @controller = Object.new
    assign_controller(@controller)
    assert_not respond_to?(:params)
    assert respond_to?(:assign_controller)

    def @controller.params
      {}
    end
    assert respond_to?(:params)
    assert respond_to?(:assign_controller)
  end
end
