# frozen_string_literal: true

require "cases/helper"

class TestFixturesTest < ActiveRecord::TestCase
  setup do
    @klass = Class.new
    @klass.include(ActiveRecord::TestFixtures)
  end

  def test_use_transactional_tests_defaults_to_true
    assert_equal true, @klass.use_transactional_tests
  end

  def test_use_transactional_tests_can_be_overridden
    @klass.use_transactional_tests = "foobar"

    assert_equal "foobar", @klass.use_transactional_tests
  end
end
