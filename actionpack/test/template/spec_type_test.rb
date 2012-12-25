require 'abstract_unit'

class ActionViewSpecTypeTest < ActiveSupport::TestCase
  def assert_view actual
    assert_equal ActionView::TestCase, actual
  end

  def refute_view actual
    refute_equal ActionView::TestCase, actual
  end

  def test_spec_type_resolves_for_matching_helper_strings
    assert_view MiniTest::Spec.spec_type("WidgetHelper")
    assert_view MiniTest::Spec.spec_type("WidgetHelperTest")
    assert_view MiniTest::Spec.spec_type("Widget Helper Test")
    # And is not case sensitive
    assert_view MiniTest::Spec.spec_type("widgethelper")
    assert_view MiniTest::Spec.spec_type("widgethelpertest")
    assert_view MiniTest::Spec.spec_type("widget helper test")
  end

  def test_spec_type_resolves_for_matching_view_strings
    assert_view MiniTest::Spec.spec_type("WidgetView")
    assert_view MiniTest::Spec.spec_type("WidgetViewTest")
    assert_view MiniTest::Spec.spec_type("Widget View Test")
    # And is not case sensitive
    assert_view MiniTest::Spec.spec_type("widgetview")
    assert_view MiniTest::Spec.spec_type("widgetviewtest")
    assert_view MiniTest::Spec.spec_type("widget view test")
  end

  def test_spec_type_wont_match_non_space_characters
    refute_view MiniTest::Spec.spec_type("Widget Helper\tTest")
    refute_view MiniTest::Spec.spec_type("Widget Helper\rTest")
    refute_view MiniTest::Spec.spec_type("Widget Helper\nTest")
    refute_view MiniTest::Spec.spec_type("Widget Helper\fTest")
    refute_view MiniTest::Spec.spec_type("Widget HelperXTest")
  end
end
