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

  test "run with only successful steps combined gives success" do
    output = capture_io do
      @CI.run("CI", nil) do
        step "Success!", "true"
        step "Success again!", "true"
      end
    end.to_s

    assert_match(/CI passed/, output)
    assert @CI.success?
  end

  test "run with successful and failed steps combined gives failure" do
    output = capture_io do
      assert_raises(SystemExit) do
        @CI.run("CI", nil) do
          step "Success!", "true"
          step "Failed!", "false"
        end
      end
    end.to_s

    assert_match(/CI failed/, output)
    assert_not @CI.success?
  end

  test "run with successful and failed steps combined presents a failure summary" do
    output = capture_io do
      assert_raises(SystemExit) do
        @CI.run("CI", nil) do
          step "Success!", "true"
          step "Failed!", "false"
          step "Also success!", "true"
          step "Also failed!", "false"
        end
      end
    end.to_s

    assert_no_match(/↳ Success/, output)
    assert_no_match(/↳ Also success/, output)
    assert_match(/↳ Failed! failed/, output)
    assert_match(/↳ Also failed! failed/, output)
  end

  test "run with only one failing step does not print a failure summary" do
    output = capture_io do
      assert_raises(SystemExit) do
        @CI.run("CI", nil) do
          step "Failed!", "false"
        end
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

  test "sequential group with all passing steps" do
    output = capture_io do
      @CI.group("Checks") do
        step "Pass 1", "true"
        step "Pass 2", "true"
      end
    end.to_s

    assert @CI.success?
    assert_match(/Pass 1 passed/, output)
    assert_match(/Pass 2 passed/, output)
  end

  test "sequential group with a failing step" do
    output = capture_io do
      @CI.group("Checks") do
        step "Pass", "true"
        step "Fail", "false"
      end
    end.to_s

    assert_not @CI.success?
    assert_match(/Fail failed/, output)
  end

  test "parallel group with all passing steps" do
    output = capture_io do
      @CI.group("Checks", parallel: 2) do
        step "Pass 1", "true"
        step "Pass 2", "true"
      end
    end.to_s

    assert @CI.success?
    assert_match(/Pass 1 passed/, output)
    assert_match(/Pass 2 passed/, output)
  end

  test "parallel group with a failing step" do
    output = capture_io do
      @CI.group("Checks", parallel: 2) do
        step "Pass", "true"
        step "Fail", "false"
      end
    end.to_s

    assert_not @CI.success?
    assert_match(/Fail failed/, output)
  end

  test "parallel group provides a tty via pty" do
    begin
      require "pty"
    rescue LoadError
      skip "PTY not available"
    end

    output = capture_io do
      @CI.group("Checks", parallel: 2) do
        step "TTY", "sh", "-c", "test -t 1"
      end
    end.to_s

    assert_match(/TTY passed/, output)
  end

  test "parallel group falls back to open3 when pty is unavailable" do
    assert_called_on_instance_of(ActiveSupport::ContinuousIntegration::Group, :pty_available?, returns: false) do
      output = capture_io do
        @CI.group("Checks", parallel: 2) do
          step "TTY", "sh", "-c", "test -t 1"
        end
      end.to_s

      assert_match(/TTY failed/, output)
    end
  end

  test "parallel group timing" do
    capture_io do
      started = Time.now.to_f
      @CI.group("Checks", parallel: 2) do
        step "Sleep 1", "sleep 0.2"
        step "Sleep 2", "sleep 0.2"
      end
      elapsed = Time.now.to_f - started

      assert elapsed < 0.35, "Expected parallel execution to complete in ~0.2s, took #{elapsed}s"
    end

    assert @CI.success?
  end

  test "sub-groups cannot be parallelized" do
    exception = assert_raises ArgumentError do
      capture_io do
        @CI.group("Outer", parallel: 2) do
          group "Inner", parallel: 2 do
            step "Test", "true"
          end
        end
      end
    end
    assert_equal "Sub-groups cannot be parallelized. Remove the `parallel:` option from the \"Inner\" group.", exception.message
  end

  test "nested group within sequential group" do
    output = capture_io do
      @CI.group("Outer") do
        step "Style", "true"
        group "Tests" do
          step "Unit", "true"
          step "System", "true"
        end
      end
    end.to_s

    assert @CI.success?
    assert_match(/Unit passed/, output)
    assert_match(/System passed/, output)
  end

  test "nested group within parallel group" do
    output = capture_io do
      @CI.group("Checks", parallel: 2) do
        step "Style", "true"
        group "Tests" do
          step "Unit", "true"
          step "System", "true"
        end
      end
    end.to_s

    assert @CI.success?
    assert_match(/Style passed/, output)
    assert_match(/Unit passed/, output)
    assert_match(/System passed/, output)
  end

  test "step restores previous signal handler" do
    custom_handler = proc { }
    Signal.trap("INT", custom_handler)

    capture_io { @CI.step "Pass", "true" }

    current = Signal.trap("INT", "DEFAULT")
    assert_equal custom_handler, current
  ensure
    Signal.trap("INT", "DEFAULT")
  end

  test "parallel group restores previous signal handler" do
    custom_handler = proc { }
    Signal.trap("INT", custom_handler)

    capture_io do
      @CI.group("Checks", parallel: 2) do
        step "Pass", "true"
      end
    end

    current = Signal.trap("INT", "DEFAULT")
    assert_equal custom_handler, current
  ensure
    Signal.trap("INT", "DEFAULT")
  end

  test "parallel group handles spawn errors as failed steps" do
    Dir.mktmpdir do |dir|
      script = File.join(dir, "nope.sh")
      File.write(script, "#!/bin/sh\nexit 0")
      File.chmod(0o000, script)

      output = capture_io do
        @CI.group("Checks", parallel: 2) do
          step "No permission", script
        end
      end.to_s

      assert_not @CI.success?
      assert_match(/No permission failed/, output)
    end
  end

  test "parallel group cleans up temp files on completion" do
    temp_files_before = Dir.glob(File.join(Dir.tmpdir, "ci-*.log"))

    capture_io do
      @CI.group("Checks", parallel: 2) do
        step "Pass", "true"
        step "Fail", "false"
      end
    end

    temp_files_after = Dir.glob(File.join(Dir.tmpdir, "ci-*.log"))
    assert_equal temp_files_before, temp_files_after
  end

  %w[-g --group].each do |flag|
    test "#{flag} selects a group by exact case-insensitive name" do
      output = run_ci([flag, "style"]) do
        step "Setup", "true"
        group "Style", parallel: 2 do
          step "Style check", "true"
          group "Nested" do
            step "Nested style check", "true"
          end
        end
        group "Styles" do
          step "Plural style check", "true"
        end
      end

      assert_match(/Style check passed/, output)
      assert_match(/Nested style check passed/, output)
      assert_no_match(/Setup passed/, output)
      assert_no_match(/Plural style check passed/, output)
    end
  end

  %w[-s --step].each do |flag|
    test "#{flag} selects a step by exact case-insensitive name" do
      output = run_ci([flag, "security: gem audit"]) do
        group "Checks", parallel: 2 do
          step "Security: Gem audit", "true"
          step "Security: Gem audit update", "true"
          step "Style: Ruby", "true"
        end
      end

      assert_match(/Security: Gem audit passed/, output)
      assert_no_match(/Security: Gem audit update passed/, output)
      assert_no_match(/Style: Ruby passed/, output)
    end
  end

  test "repeated group and step selectors are ORed within type and ANDed across types" do
    output = run_ci([
      "--group", "style", "-g", "security",
      "--step", "style check", "-s", "security check"
    ]) do
      group "Style", parallel: 2 do
        step "Style check", "true"
        step "Extra style check", "true"
      end
      group "Security", parallel: 2 do
        step "Security check", "true"
      end
      group "Tests" do
        step "Style check", "true"
      end
    end

    assert_equal 1, output.scan(/Style check passed/).size
    assert_match(/Security check passed/, output)
    assert_no_match(/Extra style check passed/, output)
  end

  test "group selector finds nested groups within unmatched sequential and parallel groups" do
    output = run_ci(["--group", "tests"]) do
      group "Sequential checks" do
        step "Sequential direct check", "true"
        group "Tests" do
          step "Sequential nested test", "true"
        end
      end

      group "Parallel checks", parallel: 2 do
        step "Parallel direct check", "true"
        group "Tests" do
          step "Parallel nested test", "true"
        end
      end
    end

    assert_match(/Sequential nested test passed/, output)
    assert_match(/Parallel nested test passed/, output)
    assert_no_match(/Sequential direct check passed/, output)
    assert_no_match(/Parallel direct check passed/, output)
  end

  test "filtered run exits with an error when no step matches" do
    output = with_argv(["--step", "security"]) do
      capture_io do
        assert_raises SystemExit do
          @CI.run("CI", nil) do
            step "Security: Gem audit", "true"
          end
        end
      end
    end.to_s

    assert_match(/No CI steps matched/, output)
    assert_match(/security/, output)
    assert_no_match(/Security: Gem audit passed/, output)
    assert_no_match(/CI passed/, output)
  end

  %w[-h --help].each do |flag|
    test "#{flag} prints help without running CI" do
      executed = false
      output = with_argv([flag]) do
        capture_io do
          @CI.run("CI", nil) do
            executed = true
          end
        end
      end.to_s

      assert_not executed
      assert_match(/Usage: bin\/ci \[options\]/, output)
      assert_match(/--group NAME/, output)
      assert_match(/--step NAME/, output)
      assert_no_match(/CI passed/, output)
    end
  end

  test "invalid option exits with usage" do
    output = with_argv(["--unknown"]) do
      capture_io do
        assert_raises SystemExit do
          @CI.run("CI", nil) { flunk "CI should not run" }
        end
      end
    end.to_s

    assert_match(/invalid option: --unknown/, output)
    assert_match(/Usage: bin\/ci \[options\]/, output)
  end

  test "fail fast ignores unselected failing steps" do
    output = run_ci(["--fail-fast", "--step", "Selected"]) do
      step "Not selected", "false"
      step "Selected", "true"
    end

    assert_match(/Selected passed/, output)
    assert_no_match(/Not selected failed/, output)
  end

  %w[-f --fail-fast].each do |flag|
    test "run aborts immediately on failure with #{flag} flag" do
      output = with_argv([flag]) do
        capture_io do
          assert_raises SystemExit do
            @CI.run("CI", nil) do
              step "Success!", "true"
              step "Failed!", "false"
              step "Should not run", "true"
            end
          end
        end
      end.to_s

      assert_no_match(/Should not run/, output)
    end

    test "parallel group stops launching new steps with #{flag} flag" do
      output = with_argv([flag]) do
        capture_io do
          assert_raises SystemExit do
            @CI.run("CI", nil) do
              group "Checks", parallel: 2 do
                step "Fail", "false"
                step "Should not run 1", "sleep", "0.1"
                step "Should not run 2", "sleep", "0.1"
                step "Should not run 3", "sleep", "0.1"
              end
            end
          end
        end
      end.to_s

      # With parallel: 2, one thread gets "Fail" and the other may dequeue one
      # task before observing the failure — but subsequent tasks must be skipped.
      assert_no_match(/Should not run 3/, output)
    end
  end

  private
    def run_ci(argv, &block)
      with_argv(argv) do
        capture_io { @CI.run("CI", nil, &block) }
      end.to_s
    end

    def with_argv(argv)
      original_argv = ARGV.dup
      ARGV.replace(argv)

      yield
    ensure
      ARGV.replace(original_argv)
    end
end
