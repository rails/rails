# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"

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

  test "retaining leading bracket" do
    result = ActionDispatch::ParamBuilder.from_query_string("[foo]=bar")
    assert_equal({ "[foo]" => "bar" }, result)

    result = ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz")
    assert_equal({ "[foo]" => { "bar" => "baz" } }, result)
  end

  class RactorTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::RactorsAssertions

    test "default builder is Ractor shareable" do
      assert_ractor_shareable ActionDispatch::ParamBuilder.default
    end

    test "parses a query string through the default builder on a non-main Ractor" do
      params = on_ractor { ActionDispatch::ParamBuilder.from_query_string("a=1&b[c]=2") }

      assert_equal({ "a" => "1", "b" => { "c" => "2" } }, params)
    end
  end
end
