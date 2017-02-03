require "abstract_unit"

# These test cases were added to test that cherry-picking the json extensions
# works correctly, primarily for dependencies problems reported in #16131. They
# need to be executed in isolation to reproduce the scenario correctly, because
# other test cases might have already loaded additional dependencies.

class JsonCherryPickTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def test_time_as_json
    require_or_skip "active_support/core_ext/object/json"

    expected = Time.new(2004, 7, 25)
    actual   = Time.parse(expected.as_json)

    assert_equal expected, actual
  end

  def test_date_as_json
    require_or_skip "active_support/core_ext/object/json"

    expected = Date.new(2004, 7, 25)
    actual   = Date.parse(expected.as_json)

    assert_equal expected, actual
  end

  def test_datetime_as_json
    require_or_skip "active_support/core_ext/object/json"

    expected = DateTime.new(2004, 7, 25)
    actual   = DateTime.parse(expected.as_json)

    assert_equal expected, actual
  end

  private
    def require_or_skip(file)
      require(file) || skip("'#{file}' was already loaded")
    end
end
