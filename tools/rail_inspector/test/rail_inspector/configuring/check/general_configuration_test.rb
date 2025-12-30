# frozen_string_literal: true

require "test_helper"
require "rail_inspector/configuring"

class TestGeneralConfiguration < ActiveSupport::TestCase
  def test_errors_when_configuration_out_of_order
    with_general_config <<~MD
      #### `config.b`

      #### `config.a`
    MD

    check([:a, :b]).check

    assert_not_empty checker.errors
  end

  def test_no_errors_when_configuration_alphabetical
    with_general_config <<~MD
      #### `config.a`

      #### `config.b`
    MD

    check([:a, :b]).check

    assert_empty checker.errors
  end

  private
    def check(expected_accessors)
      @check ||= RailInspector::Configuring::Check::GeneralConfiguration.new(checker, expected_accessors: expected_accessors)
    end

    def checker
      @checker ||= RailInspector::Configuring.new("../..")
    end

    HEADER = [
      "### Rails General Configuration",
      "",
      "The following configuration methods are to be called on a `Rails::Railtie` object, such as a subclass of `Rails::Engine` or `Rails::Application`.",
      "",
    ].freeze

    def with_general_config(markdown)
      checker.doc.general_config = HEADER + markdown.split("\n")
    end
end
