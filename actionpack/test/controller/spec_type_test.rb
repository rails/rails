require "abstract_unit"

class ApplicationController < ActionController::Base; end
class ModelsController      < ApplicationController;  end

class ActionControllerSpecTypeTest < ActiveSupport::TestCase
  def assert_controller actual
    assert_equal ActionController::TestCase, actual
  end

  def refute_controller actual
    refute_equal ActionController::TestCase, actual
  end

  def test_spec_type_resolves_for_class_constants
    assert_controller MiniTest::Spec.spec_type(ApplicationController)
    assert_controller MiniTest::Spec.spec_type(ModelsController)
  end

  def test_spec_type_resolves_for_matching_strings
    assert_controller MiniTest::Spec.spec_type("WidgetController")
    assert_controller MiniTest::Spec.spec_type("WidgetControllerTest")
    assert_controller MiniTest::Spec.spec_type("Widget Controller Test")
    # And is not case sensitive
    assert_controller MiniTest::Spec.spec_type("widgetcontroller")
    assert_controller MiniTest::Spec.spec_type("widgetcontrollertest")
    assert_controller MiniTest::Spec.spec_type("widget controller test")
  end

  def test_spec_type_wont_match_non_space_characters
    refute_controller MiniTest::Spec.spec_type("Widget Controller\tTest")
    refute_controller MiniTest::Spec.spec_type("Widget Controller\rTest")
    refute_controller MiniTest::Spec.spec_type("Widget Controller\nTest")
    refute_controller MiniTest::Spec.spec_type("Widget Controller\fTest")
    refute_controller MiniTest::Spec.spec_type("Widget ControllerXTest")
  end
end
