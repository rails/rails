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

  test "filter_key_without_procs matches key filters without invoking procs" do
    calls = []
    parameter_filter = ActiveSupport::ParameterFilter.new(
      [:password, ->(key, value) { calls << key; value.replace("[REDACTED]") }],
      mask: "[MASKED]"
    )

    assert_equal [true, "[MASKED]"], parameter_filter.filter_key_without_procs("password")
    assert_equal [false, nil], parameter_filter.filter_key_without_procs("other")
    assert_empty calls
    assert_equal "[REDACTED]", parameter_filter.filter_param("other", "visible")
  end

  test "filter_key_without_procs distinguishes a nil mask from no match" do
    parameter_filter = ActiveSupport::ParameterFilter.new([:password], mask: nil)

    assert_equal [true, nil], parameter_filter.filter_key_without_procs("password")
    assert_equal [false, nil], parameter_filter.filter_key_without_procs("other")
  end

  test "filter_key_without_procs checks deep keys without invoking procs" do
    calls = []
    parameter_filter = ActiveSupport::ParameterFilter.new([
      "user.password", ->(key, _value) { calls << key }
    ])

    assert_equal [true, "[FILTERED]"], parameter_filter.filter_key_without_procs("user.password")
    assert_equal [false, nil], parameter_filter.filter_key_without_procs("user.other")
    assert_empty calls
  end

  test "filter_param passes the pair to a proc filter as the original params" do
    parameter_filter = ActiveSupport::ParameterFilter.new([
      ->(key, value, original_params) { value.replace("[FILTERED]") if original_params[key] == "secret" }
    ])
    assert_equal "[FILTERED]", parameter_filter.filter_param("token", "secret")
    assert_equal "visible", parameter_filter.filter_param("token", "visible")
  end

  test "filter_param can work with empty filters" do
    parameter_filter = ActiveSupport::ParameterFilter.new
    assert_equal "bar", parameter_filter.filter_param("foo", "bar")
  end

  test "filter with empty filters returns a dup of the params" do
    parameter_filter = ActiveSupport::ParameterFilter.new
    original = { "foo" => "bar" }
    filtered = parameter_filter.filter(original)

    assert_equal original, filtered
    assert_not_same original, filtered
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

  test "anchored exact-match regexp filters" do
    parameter_filter = ActiveSupport::ParameterFilter.new([/^token$/, /\Astate\z/, /password/])
    result = parameter_filter.filter("token" => "t0k3n", "state" => "abc", "password" => "pass", "user_password" => "pass", "not_secret" => "visible")
    assert_equal({ "token" => "[FILTERED]", "state" => "[FILTERED]", "password" => "[FILTERED]", "user_password" => "[FILTERED]", "not_secret" => "visible" }, result)
  end

  test "^...$ anchored regexp filters still match keys containing newlines" do
    parameter_filter = ActiveSupport::ParameterFilter.new([/^token$/])

    assert_equal "[FILTERED]", parameter_filter.filter_param("token\nfoo", "secret")
    assert_equal "[FILTERED]", parameter_filter.filter_param("foo\ntoken", "secret")
    assert_equal "[FILTERED]", parameter_filter.filter_param("foo\ntoken\nbar", "secret")
    assert_equal "visible", parameter_filter.filter_param("not_token\nfoo", "visible")
  end

  test "\\A...\\z anchored regexp filters do not match keys containing newlines" do
    parameter_filter = ActiveSupport::ParameterFilter.new([/\Atoken\z/])

    assert_equal "[FILTERED]", parameter_filter.filter_param("token", "secret")
    assert_equal "visible", parameter_filter.filter_param("token\nfoo", "visible")
    assert_equal "visible", parameter_filter.filter_param("foo\ntoken", "visible")
  end

  test "mixed-anchor regexp filters preserve their asymmetric semantics" do
    first_line_filter = ActiveSupport::ParameterFilter.new([/\Atoken$/])
    assert_equal "[FILTERED]", first_line_filter.filter_param("token", "secret")
    assert_equal "[FILTERED]", first_line_filter.filter_param("token\nfoo", "secret")
    assert_equal "visible", first_line_filter.filter_param("foo\ntoken", "visible")

    last_line_filter = ActiveSupport::ParameterFilter.new([/^token\z/])
    assert_equal "[FILTERED]", last_line_filter.filter_param("token", "secret")
    assert_equal "visible", last_line_filter.filter_param("token\nfoo", "visible")
    assert_equal "[FILTERED]", last_line_filter.filter_param("foo\ntoken", "secret")
  end

  test "precompile_filters" do
    patterns = [/A.a/, /b.B/i, "ccC", :ddD]
    keys = ["Aaa", "Bbb", "Ccc", "Ddd"]
    deep_patterns = [/A\.a/, /b\.B/i, "c.C", :"d.D"]
    deep_keys = ["A.a", "B.b", "C.c", "D.d"]
    procs = [proc { }, proc { }]

    precompiled = ActiveSupport::ParameterFilter.precompile_filters([*patterns, *deep_patterns, *procs])

    assert_equal 2, precompiled.grep(Regexp).length
    assert_equal 2 + procs.length, precompiled.length

    regexp = precompiled.grep(Regexp).first
    keys.each { |key| assert_match regexp, key }
    assert_no_match regexp, keys.first.swapcase

    deep_regexp = precompiled.grep(Regexp).last
    deep_keys.each { |deep_key| assert_match deep_regexp, deep_key }
    assert_no_match deep_regexp, deep_keys.first.swapcase

    assert_equal procs, precompiled & procs
  end

  test "precompile_filters eliminate dead patterns" do
    assert_equal [/token/i], ActiveSupport::ParameterFilter.precompile_filters(["user.token", "token"])
    assert_equal [/password/i], ActiveSupport::ParameterFilter.precompile_filters(["user_password", "password"])
  end

  test "precompile_filters preserves nested key matching alongside deep filters" do
    filters = [/\Atoken\z/, "credit_card.number"]
    params = {
      "account" => { "token" => "secret", "name" => "visible" },
      "accounts" => [{ "token" => "secret" }],
      "credit_card" => { "number" => "secret", "name" => "visible" }
    }
    expected = {
      "account" => { "token" => "[FILTERED]", "name" => "visible" },
      "accounts" => [{ "token" => "[FILTERED]" }],
      "credit_card" => { "number" => "[FILTERED]", "name" => "visible" }
    }

    assert_equal expected, ActiveSupport::ParameterFilter.new(filters).filter(params)
    precompiled = ActiveSupport::ParameterFilter.precompile_filters(filters)
    assert_equal expected, ActiveSupport::ParameterFilter.new(precompiled).filter(params)
  end

  test "precompile_filters preserves case insensitive string filters alongside regexps" do
    filters = [/token/, :token]
    params = { "TOKEN" => "secret", "access_TOKEN" => "secret", "name" => "visible" }
    expected = { "TOKEN" => "[FILTERED]", "access_TOKEN" => "[FILTERED]", "name" => "visible" }

    assert_equal expected, ActiveSupport::ParameterFilter.new(filters).filter(params)
    precompiled = ActiveSupport::ParameterFilter.precompile_filters(filters)
    assert_equal expected, ActiveSupport::ParameterFilter.new(precompiled).filter(params)
  end

  test "precompile_filters preserves partial string filters alongside anchored regexps" do
    filters = [/\Atoken\z/i, :token]
    params = { "access_token" => "secret", "token_confirmation" => "secret", "name" => "visible" }
    expected = { "access_token" => "[FILTERED]", "token_confirmation" => "[FILTERED]", "name" => "visible" }

    assert_equal expected, ActiveSupport::ParameterFilter.new(filters).filter(params)
    precompiled = ActiveSupport::ParameterFilter.precompile_filters(filters)
    assert_equal expected, ActiveSupport::ParameterFilter.new(precompiled).filter(params)
  end

  test "precompile_filters preserves string filters alongside end anchored regexps" do
    filters = [/token\z/, :token]
    params = { "token_x" => "secret", "name" => "visible" }
    expected = { "token_x" => "[FILTERED]", "name" => "visible" }

    assert_equal expected, ActiveSupport::ParameterFilter.new(filters).filter(params)
    precompiled = ActiveSupport::ParameterFilter.precompile_filters(filters)
    assert_equal expected, ActiveSupport::ParameterFilter.new(precompiled).filter(params)
  end

  test "precompile_filters preserves deep string filters alongside regexps" do
    filters = [/\Auser\.token\z/, "user.token"]
    params = { "USER" => { "TOKEN" => "secret" }, "user" => { "token_confirmation" => "secret" } }
    expected = { "USER" => { "TOKEN" => "[FILTERED]" }, "user" => { "token_confirmation" => "[FILTERED]" } }

    assert_equal expected, ActiveSupport::ParameterFilter.new(filters).filter(params)
    precompiled = ActiveSupport::ParameterFilter.precompile_filters(filters)
    assert_equal expected, ActiveSupport::ParameterFilter.new(precompiled).filter(params)
  end
end
