# frozen_string_literal: true

require "active_support/deprecator"
require "active_support/test_case"
require "active_support/testing/autorun"
require "rails/test_unit/test_parser"

class TestParserTest < ActiveSupport::TestCase
  def test_parser
    example_test = <<~RUBY
      require "test_helper"

      class ExampleTest < ActiveSupport::TestCase
        def test_method
          assert true


        end

        def test_oneline; assert true; end

        test "declarative" do
          assert true
        end

        test("declarative w/parens") do
          assert true

        end

        self.test "declarative explicit receiver" do
          assert true
        end

        test("declarative oneline") { assert true }

        test("declarative oneline do") do assert true end

        test("declarative multiline w/ braces") {
          assert true
          refute false
        }
      end
    RUBY

    actual_map = Rails::TestUnit::TestParser.definitions_for(example_test, "example_test.rb")
    expected_map = {
      4 => 8,   # test_method
      10 => 10, # test_oneline
      12 => 14, # declarative
      16 => 19, # declarative w/parens
      21 => 23, # declarative explicit receiver
      25 => 25, # declarative oneline
      27 => 27, # declarative oneilne do
      29 => 32  # declarative multiline w/braces
    }
    assert_equal expected_map, actual_map
  end
end
