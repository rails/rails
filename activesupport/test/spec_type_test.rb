require "abstract_unit"
require "active_record"

class SomeRandomModel < ActiveRecord::Base; end

class SpecTypeTest < ActiveSupport::TestCase
  def assert_support actual
    assert_equal ActiveSupport::TestCase, actual
  end

  def assert_spec actual
    assert_equal MiniTest::Spec, actual
  end

  def test_spec_type_resolves_for_active_record_constants
    assert_support MiniTest::Spec.spec_type(SomeRandomModel)
  end

  def test_spec_type_doesnt_resolve_random_strings
    assert_spec MiniTest::Spec.spec_type("Unmatched String")
  end
end
