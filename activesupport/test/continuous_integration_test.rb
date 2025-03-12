# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/continuous_integration"

class ContinuousIntegrationTest < ActiveSupport::TestCase
  setup { @CI = ActiveSupport::ContinuousIntegration.new }

  test "successful step" do
    output = capture_io { @CI.step "Success!", "true" }.to_s
    assert_match(/Success! passed/, output)
    assert @CI.success?
  end

  test "failed step" do
    output = capture_io { @CI.step "Failed!", "false" }.to_s
    assert_match(/Failed! failed/, output)
    assert_not @CI.success?
  end

  test "report with only successful steps combined gives success" do
    output = capture_io do
      @CI.report("CI") do
        step "Success!", "true"
        step "Success again!", "true"
      end
    end.to_s

    assert_match(/CI passed/, output)
    assert @CI.success?
  end

  test "report with successful and failed steps combined gives failure" do
    output = capture_io do
      @CI.report("CI") do
        step "Success!", "true"
        step "Failed!", "false"
      end
    end.to_s

    assert_match(/CI failed/, output)
    assert_not @CI.success?
  end

  test "echo uses terminal coloring" do
    output = capture_io { @CI.echo "Hello", type: :success }.first.to_s
    assert_equal "\e[1;32mHello\e[0m\n", output
  end

  test "heading" do
    output = capture_io { @CI.heading "Hello", "To all of you" }.first.to_s
    assert_match(/Hello[\s\S]*To all of you/, output)
  end

  test "failure output" do
    output = capture_io { @CI.failure "This sucks", "But such is the life of programming sometimes" }.first.to_s
    assert_equal "\e[1;31m\n\nThis sucks\e[0m\n\e[1;90mBut such is the life of programming sometimes\n\e[0m\n", output
  end
end
