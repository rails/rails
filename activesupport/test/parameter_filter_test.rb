# frozen_string_literal: true

require "abstract_unit"
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
        value.reverse! if key =~ /bargain/
      }
      filter_words << lambda { |key, value, original_params|
        value.replace("world!") if original_params["barg"]["blah"] == "bar" && key == "hello"
      }

      parameter_filter = ActiveSupport::ParameterFilter.new(filter_words)
      before_filter["barg"] = { :bargain => "gain", "blah" => "bar", "bar" => { "bargain" => { "blah" => "foo", "hello" => "world" } } }
      after_filter["barg"]  = { :bargain => "niag", "blah" => "[FILTERED]", "bar" => { "bargain" => { "blah" => "[FILTERED]", "hello" => "world!" } } }

      assert_equal after_filter, parameter_filter.filter(before_filter)
    end
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
end
