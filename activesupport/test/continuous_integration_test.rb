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

  test "report with successful and failed steps combined presents a failure summary" do
    output = capture_io do
      @CI.report("CI") do
        step "Success!", "true"
        step "Failed!", "false"
        step "Also success!", "true"
        step "Also failed!", "false"
      end
    end.to_s

    assert_no_match(/↳ Success/, output)
    assert_no_match(/↳ Also success/, output)
    assert_match(/↳ Failed! failed/, output)
    assert_match(/↳ Also failed! failed/, output)
  end

  test "report with only one failing step does not print a failure summary" do
    output = capture_io do
      @CI.report("CI") do
        step "Failed!", "false"
      end
    end.to_s

    assert_no_match(/↳ Failed/, output)
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

  %w[-f --fail-fast].each do |flag|
    test "report aborts immediately on failure with #{flag} flag" do
      output = with_argv([flag]) do
        capture_io do
          assert_raises SystemExit do
            @CI.report("CI") do
              step "Success!", "true"
              step "Failed!", "false"
              step "Should not run", "true"
            end
          end
        end
      end.to_s

      assert_no_match(/Should not run/, output)
    end
  end

  test "groups filters correctly based on -g/--group flags" do
    group_ci = proc do
      step "Setup", "true"

      group "lint" do
        step "RuboCop", "true"
      end

      group "backend" do
        group "unit" do
          group "models" do
            step "User model", "true"
          end
        end
        group "integration" do
          step "API", "true"
        end
      end

      group "frontend" do
        step "Jest", "true"
      end
    end

    no_filter = run_ci_block([], &group_ci)
    assert_match(/Group: lint/, no_filter)
    assert_match(/Group: backend/, no_filter)
    assert_match(/Group: frontend/, no_filter)
    assert_match(/Setup passed/, no_filter)
    assert_match(/Jest passed/, no_filter)

    top_level_filter = run_ci_block(["-g", "lint"], &group_ci)
    assert_match(/Group: lint/, top_level_filter)
    assert_match(/RuboCop passed/, top_level_filter)
    assert_no_match(/Setup/, top_level_filter)
    assert_no_match(/Group: backend/, top_level_filter)

    long_flag = run_ci_block(["--group", "lint"], &group_ci)
    assert_match(/Group: lint/, long_flag)

    nested_filter = run_ci_block(["-g", "models"], &group_ci)
    assert_match(/Group: models/, nested_filter)
    assert_match(/User model passed/, nested_filter)
    assert_no_match(/Group: unit/, nested_filter)
    assert_no_match(/Group: backend/, nested_filter)

    parent_filter = run_ci_block(["-g", "backend"], &group_ci)
    assert_match(/Group: backend/, parent_filter)
    assert_match(/Group: unit/, parent_filter)
    assert_match(/Group: models/, parent_filter)
    assert_no_match(/Group: lint/, parent_filter)

    multiple_filters = run_ci_block(["-g", "lint,frontend"], &group_ci)
    assert_match(/Group: lint/, multiple_filters)
    assert_match(/Group: frontend/, multiple_filters)
    assert_no_match(/Group: backend/, multiple_filters)
  end

  private
    def with_argv(argv)
      original_argv = ARGV.dup
      ARGV.replace(argv)

      yield
    ensure
      ARGV.replace(original_argv)
    end

    def run_ci_block(argv, &block)
      with_argv(argv) do
        capture_io { @CI.report("CI", &block) }
      end.to_s
    end
end
