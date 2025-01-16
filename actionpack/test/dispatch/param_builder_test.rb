# frozen_string_literal: true

require "abstract_unit"

class ParamBuilderTest < ActiveSupport::TestCase
  # Much of the behavioral details are covered by long-standing
  # integration tests in test/request/query_string_parsing_test.rb
  #
  # This test doesn't need to duplicate all of that: it just
  # offers a simple baseline of unit tests.

  test "simple query string" do
    result = ActionDispatch::ParamBuilder.from_query_string("foo=bar&baz=quux")
    assert_equal({ "foo" => "bar", "baz" => "quux" }, result)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, result
  end

  test "nested parameters" do
    result = ActionDispatch::ParamBuilder.from_query_string("foo[bar]=baz")
    assert_equal({ "foo" => { "bar" => "baz" } }, result)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, result[:foo]
  end

  if ::Rack::RELEASE.start_with?("2.")
    test "(rack 2) defaults to ignoring leading bracket" do
      assert_deprecated(ActionDispatch.deprecator) do
        result = ActionDispatch::ParamBuilder.from_query_string("[foo]=bar")
        assert_equal({ "foo" => "bar" }, result)
      end

      assert_deprecated(ActionDispatch.deprecator) do
        result = ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz")
        assert_equal({ "foo" => { "bar" => "baz" } }, result)
      end
    end
  else
    test "(rack 3) defaults to retaining leading bracket" do
      result = ActionDispatch::ParamBuilder.from_query_string("[foo]=bar")
      assert_equal({ "[foo]" => "bar" }, result)

      result = ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz")
      assert_equal({ "[foo]" => { "bar" => "baz" } }, result)
    end
  end

  test "configured for strict brackets" do
    previous_brackets = ActionDispatch::ParamBuilder.ignore_leading_brackets
    ActionDispatch::ParamBuilder.ignore_leading_brackets = false

    result = ActionDispatch::ParamBuilder.from_query_string("[foo]=bar")
    assert_equal({ "[foo]" => "bar" }, result)

    result = ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz")
    assert_equal({ "[foo]" => { "bar" => "baz" } }, result)
  ensure
    ActionDispatch::ParamBuilder.ignore_leading_brackets = previous_brackets
  end

  test "configured for ignoring leading brackets" do
    previous_brackets = ActionDispatch::ParamBuilder.ignore_leading_brackets
    ActionDispatch::ParamBuilder.ignore_leading_brackets = true

    result = ActionDispatch::ParamBuilder.from_query_string("[foo]=bar")
    assert_equal({ "foo" => "bar" }, result)

    result = ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz")
    assert_equal({ "foo" => { "bar" => "baz" } }, result)
  ensure
    ActionDispatch::ParamBuilder.ignore_leading_brackets = previous_brackets
  end
end
