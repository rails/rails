# frozen_string_literal: true

require "support/cop_helper"
require "./lib/custom_cops/refute_not"

class RefuteNotTest < ActiveSupport::TestCase
  include CopHelper

  setup do
    @cop = CustomCops::RefuteNot.new
  end

  {
    refute:             :assert_not,
    refute_empty:       :assert_not_empty,
    refute_equal:       :assert_not_equal,
    refute_in_delta:    :assert_not_in_delta,
    refute_in_epsilon:  :assert_not_in_epsilon,
    refute_includes:    :assert_not_includes,
    refute_instance_of: :assert_not_instance_of,
    refute_kind_of:     :assert_not_kind_of,
    refute_nil:         :assert_not_nil,
    refute_operator:    :assert_not_operator,
    refute_predicate:   :assert_not_predicate,
    refute_respond_to:  :assert_not_respond_to,
    refute_same:        :assert_not_same,
    refute_match:       :assert_no_match
  }.each do |refute_method, assert_method|
    test "rejects `#{refute_method}` with a single argument" do
      inspect_source(@cop, "#{refute_method} a")
      assert_offense @cop, offense_message(refute_method, assert_method)
    end

    test "rejects `#{refute_method}` with multiple arguments" do
      inspect_source(@cop, "#{refute_method} a, b, c")
      assert_offense @cop, offense_message(refute_method, assert_method)
    end

    test "autocorrects `#{refute_method}` with a single argument" do
      corrected = autocorrect_source(@cop, "#{refute_method} a")
      assert_equal "#{assert_method} a", corrected
    end

    test "autocorrects `#{refute_method}` with multiple arguments" do
      corrected = autocorrect_source(@cop, "#{refute_method} a, b, c")
      assert_equal "#{assert_method} a, b, c", corrected
    end

    test "accepts `#{assert_method}` with a single argument" do
      inspect_source(@cop, "#{assert_method} a")
      assert_empty @cop.offenses
    end

    test "accepts `#{assert_method}` with multiple arguments" do
      inspect_source(@cop, "#{assert_method} a, b, c")
      assert_empty @cop.offenses
    end
  end

  private

    def assert_offense(cop, expected_message)
      assert_not_empty cop.offenses

      offense = cop.offenses.first
      carets = "^" * offense.column_length

      assert_equal expected_message, "#{carets} #{offense.message}"
    end

    def offense_message(refute_method, assert_method)
      carets = "^" * refute_method.to_s.length
      "#{carets} Prefer `#{assert_method}` over `#{refute_method}`"
    end
end
