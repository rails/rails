require "abstract_unit"

class SpecTypeTest < ActiveSupport::TestCase
  def assert_dispatch actual
    assert_equal ActionDispatch::IntegrationTest, actual
  end

  def refute_dispatch actual
    refute_equal ActionDispatch::IntegrationTest, actual
  end

  def test_spec_type_resolves_for_matching_acceptance_strings
    assert_dispatch MiniTest::Spec.spec_type("WidgetAcceptanceTest")
    assert_dispatch MiniTest::Spec.spec_type("Widget Acceptance Test")
    assert_dispatch MiniTest::Spec.spec_type("widgetacceptancetest")
    assert_dispatch MiniTest::Spec.spec_type("widget acceptance test")
  end

  def test_spec_type_wont_match_non_space_characters_acceptance
    refute_dispatch MiniTest::Spec.spec_type("Widget Acceptance\tTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Acceptance\rTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Acceptance\nTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Acceptance\fTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget AcceptanceXTest")
  end

  def test_spec_type_resolves_for_matching_integration_strings
    assert_dispatch MiniTest::Spec.spec_type("WidgetIntegrationTest")
    assert_dispatch MiniTest::Spec.spec_type("Widget Integration Test")
    assert_dispatch MiniTest::Spec.spec_type("widgetintegrationtest")
    assert_dispatch MiniTest::Spec.spec_type("widget integration test")
  end

  def test_spec_type_wont_match_non_space_characters_integration
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\tTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\rTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\nTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\fTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget IntegrationXTest")
  end
end
