require "abstract_unit"

class SpecTypeTest < ActiveSupport::TestCase
  def assert_dispatch actual
    assert_equal ActionDispatch::TestCase, actual
  end

  def refute_dispatch actual
    refute_equal ActionDispatch::TestCase, actual
  end

  def test_spec_type_resolves_for_matching_request_strings
    assert_dispatch MiniTest::Spec.spec_type("WidgetRequestTest")
    assert_dispatch MiniTest::Spec.spec_type("Widget Request Test")
    assert_dispatch MiniTest::Spec.spec_type("widgetrequesttest")
    assert_dispatch MiniTest::Spec.spec_type("widget request test")

    assert_dispatch MiniTest::Spec.spec_type("WidgetRequest")
    assert_dispatch MiniTest::Spec.spec_type("Widget Request")
    assert_dispatch MiniTest::Spec.spec_type("widgetrequest")
    assert_dispatch MiniTest::Spec.spec_type("widget request")
  end

  def test_spec_type_wont_match_non_space_characters_request
    refute_dispatch MiniTest::Spec.spec_type("Widget Request\tTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Request\rTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Request\nTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Request\fTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget RequestXTest")
  end

  def test_spec_type_resolves_for_matching_integration_strings
    assert_dispatch MiniTest::Spec.spec_type("WidgetIntegrationTest")
    assert_dispatch MiniTest::Spec.spec_type("Widget Integration Test")
    assert_dispatch MiniTest::Spec.spec_type("widgetintegrationtest")
    assert_dispatch MiniTest::Spec.spec_type("widget integration test")

    assert_dispatch MiniTest::Spec.spec_type("WidgetIntegration")
    assert_dispatch MiniTest::Spec.spec_type("Widget Integration")
    assert_dispatch MiniTest::Spec.spec_type("widgetintegration")
    assert_dispatch MiniTest::Spec.spec_type("widget integration")
  end

  def test_spec_type_wont_match_non_space_characters_integration
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\tTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\rTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\nTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget Integration\fTest")
    refute_dispatch MiniTest::Spec.spec_type("Widget IntegrationXTest")
  end
end
