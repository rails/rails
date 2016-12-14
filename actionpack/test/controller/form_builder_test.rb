require "abstract_unit"

class FormBuilderController < ActionController::Base
  class SpecializedFormBuilder < ActionView::Helpers::FormBuilder ; end

  default_form_builder SpecializedFormBuilder
end

class ControllerFormBuilderTest < ActiveSupport::TestCase
  setup do
    @controller = FormBuilderController.new
  end

  def test_default_form_builder_assigned
    assert_equal FormBuilderController::SpecializedFormBuilder, @controller.default_form_builder
  end
end
