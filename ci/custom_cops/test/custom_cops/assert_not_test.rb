# frozen_string_literal: true

require "support/cop_helper"
require_relative "../../lib/custom_cops/assert_not"

class AssertNotTest < ActiveSupport::TestCase
  include CopHelper

  setup do
    @cop = CustomCops::AssertNot.new
  end

  test "rejects 'assert !'" do
    inspect_source @cop, "assert !x"
    assert_offense @cop, "^^^^^^^^^ Prefer `assert_not` over `assert !`"
  end

  test "rejects 'assert !' with a failure message" do
    inspect_source @cop, "assert !x, 'a failure message'"
    assert_offense @cop, "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Prefer `assert_not` over `assert !`"
  end

  test "rejects 'assert !' with a complex value" do
    inspect_source @cop, "assert !a.b(c)"
    assert_offense @cop, "^^^^^^^^^^^^^^ Prefer `assert_not` over `assert !`"
  end

  test "autocorrects `assert !`" do
    corrected = autocorrect_source(@cop, "assert !false")
    assert_equal "assert_not false", corrected
  end

  test "autocorrects 'assert !' with a failure message" do
    corrected = autocorrect_source(@cop, "assert !x, 'a failure message'")
    assert_equal "assert_not x, 'a failure message'", corrected
  end

  test "autocorrects `assert !` with extra spaces" do
    corrected = autocorrect_source(@cop, "assert   !  false")
    assert_equal "assert_not false", corrected
  end

  test "autocorrects `assert !` with parentheses" do
    corrected = autocorrect_source(@cop, "assert(!false)")
    assert_equal "assert_not(false)", corrected
  end

  test "accepts `assert_not`" do
    inspect_source @cop, "assert_not x"
    assert_empty @cop.offenses
  end
end
