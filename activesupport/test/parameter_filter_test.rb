# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/hash"
require "active_support/parameter_filter"

class ParameterFilterTest < ActiveSupport::TestCase
  test "process parameter filter" do
    test_hashes = [
    [{ "foo" => "bar" }, { "foo" => "bar" }, %w'food'],
    [{ "foo" => "bar" }, { "foo" => "[FILTERED]" }, %w'foo'],
    [{ "foo" => "bar", "bar" => "foo" }, { "foo" => "[FILTERED]", "bar" => "foo" }, %w'foo baz'],
    [{ "foo" => "bar", "baz" => "foo" }, { "foo" => "[FILTERED]", "baz" => "[FILTERED]" }, %w'foo baz'],
    [{ "bar" => { "foo" => "bar", "bar" => "foo" } }, { "bar" => { "foo" => "[FILTERED]", "bar" => "foo" } }, %w'fo'],
    [{ "foo" => { "foo" => "bar", "bar" => "foo" } }, { "foo" => "[FILTERED]" }, %w'f banana'],
    [{ "deep" => { "cc" => { "code" => "bar", "bar" => "foo" }, "ss" => { "code" => "bar" } } }, { "deep" => { "cc" => { "code" => "[FILTERED]", "bar" => "foo" }, "ss" => { "code" => "bar" } } }, %w'deep.cc.code'],
    [{ "baz" => [{ "foo" => "baz" }, "1"] }, { "baz" => [{ "foo" => "[FILTERED]" }, "1"] }, [/foo/]]]

    test_hashes.each do |before_filter, after_filter, filter_words|
      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words)
      assert_equal after_filter, parameter_filter.filter(before_filter)

      filter_words << "blah"
      filter_words << lambda { |key, value|
        value.reverse! if /bargain/.match?(key)
      }
      filter_words << lambda { |key, value, original_params|
        value.replace("world!") if original_params["barg"]["blah"] == "bar" && key == "hello"
      }

      filter_words << lambda { |key, value|
        value.upcase! if key == "array_elements"
      }

      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words)
      before_filter["barg"] = { :bargain => "gain", "blah" => "bar", "bar" => { "bargain" => { "blah" => "foo", "hello" => "world" } } }
      after_filter["barg"]  = { :bargain => "niag", "blah" => "[FILTERED]", "bar" => { "bargain" => { "blah" => "[FILTERED]", "hello" => "world!" } } }

      before_filter["array_elements"] = %w(element1 element2)
      after_filter["array_elements"] = %w(ELEMENT1 ELEMENT2)

      assert_equal after_filter, parameter_filter.filter(before_filter)
    end
  end

  test "filter should return mask option when value is filtered" do
    mask = Object.new.freeze
    test_hashes = [
    [{ "foo" => "bar" }, { "foo" => "bar" }, %w'food'],
    [{ "foo" => "bar" }, { "foo" => mask }, %w'foo'],
    [{ "foo" => "bar", "bar" => "foo" }, { "foo" => mask, "bar" => "foo" }, %w'foo baz'],
    [{ "foo" => "bar", "baz" => "foo" }, { "foo" => mask, "baz" => mask }, %w'foo baz'],
    [{ "bar" => { "foo" => "bar", "bar" => "foo" } }, { "bar" => { "foo" => mask, "bar" => "foo" } }, %w'fo'],
    [{ "foo" => { "foo" => "bar", "bar" => "foo" } }, { "foo" => mask }, %w'f banana'],
    [{ "deep" => { "cc" => { "code" => "bar", "bar" => "foo" }, "ss" => { "code" => "bar" } } }, { "deep" => { "cc" => { "code" => mask, "bar" => "foo" }, "ss" => { "code" => "bar" } } }, %w'deep.cc.code'],
    [{ "baz" => [{ "foo" => "baz" }, "1"] }, { "baz" => [{ "foo" => mask }, "1"] }, [/foo/]]]

    test_hashes.each do |before_filter, after_filter, filter_words|
      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words, mask: mask)
      assert_equal after_filter, parameter_filter.filter(before_filter)

      filter_words << "blah"
      filter_words << lambda { |key, value|
        value.reverse! if /bargain/.match?(key)
      }
      filter_words << lambda { |key, value, original_params|
        value.replace("world!") if original_params["barg"]["blah"] == "bar" && key == "hello"
      }

      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words, mask: mask)
      before_filter["barg"] = { :bargain => "gain", "blah" => "bar", "bar" => { "bargain" => { "blah" => "foo", "hello" => "world" } } }
      after_filter["barg"]  = { :bargain => "niag", "blah" => mask, "bar" => { "bargain" => { "blah" => mask, "hello" => "world!" } } }

      assert_equal after_filter, parameter_filter.filter(before_filter)
    end
  end

  test "filter_param" do
    parameter_filter = ActiveSupport::ParameterFilter.new(["foo", /bar/])
    assert_equal "[FILTERED]", parameter_filter.filter_param("food", "secret value")
    assert_equal "[FILTERED]", parameter_filter.filter_param("baz.foo", "secret value")
    assert_equal "[FILTERED]", parameter_filter.filter_param("barbar", "secret value")
    assert_equal "non secret value", parameter_filter.filter_param("baz", "non secret value")
  end

  test "filter_param can work with empty filters" do
    parameter_filter = ActiveSupport::ParameterFilter.new
    assert_equal "bar", parameter_filter.filter_param("foo", "bar")
  end

  test "parameter filter should maintain hash with indifferent access" do
    test_hashes = [
      [{ "foo" => "bar" }.with_indifferent_access, ["blah"]],
      [{ "foo" => "bar" }.with_indifferent_access, []]
    ]

    test_hashes.each do |before_filter, filter_words|
      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words)
      assert_instance_of ActiveSupport::HashWithIndifferentAccess,
                         parameter_filter.filter(before_filter)
    end
  end

  test "filter_param should return mask option when value is filtered" do
    mask = Object.new.freeze
    parameter_filter = ActiveSupport::ParameterFilter.new(["foo", /bar/], mask: mask)
    assert_equal mask, parameter_filter.filter_param("food", "secret value")
    assert_equal mask, parameter_filter.filter_param("baz.foo", "secret value")
    assert_equal mask, parameter_filter.filter_param("barbar", "secret value")
    assert_equal "non secret value", parameter_filter.filter_param("baz", "non secret value")
  end

  test "process parameter filter with hash having integer keys" do
    test_hashes = [
      [{ 13 => "bar" }, { 13 => "[FILTERED]" }, %w'13'],
      [{ 20 => "bar" }, { 20 => "bar" }, %w'13'],
    ]

    test_hashes.each do |before_filter, after_filter, filter_words|
      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words)
      assert_equal after_filter, parameter_filter.filter(before_filter)
    end
  end
end
