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
                step "Should not run 1", "true"
                step "Should not run 2", "true"
                step "Should not run 3", "true"
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
    def with_argv(argv)
      original_argv = ARGV.dup
      ARGV.replace(argv)

      yield
    ensure
      ARGV.replace(original_argv)
    end
end
