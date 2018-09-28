# frozen_string_literal: true

require "abstract_unit"
require "console_helpers"

class Rails::Engine::CommandsTest < ActiveSupport::TestCase
  include ConsoleHelpers

  def setup
    @destination_root = Dir.mktmpdir("bukkits")
    Dir.chdir(@destination_root) { `bundle exec rails plugin new bukkits --mountable` }
  end

  def teardown
    FileUtils.rm_rf(@destination_root)
  end

  def test_help_command_work_inside_engine
    output = capture(:stderr) do
      Dir.chdir(plugin_path) { `bin/rails --help` }
    end
    assert_no_match "NameError", output
  end

  def test_runner_command_work_inside_engine
    output = capture(:stdout) do
      Dir.chdir(plugin_path) { system({"SKIP_REQUIRE_WEBPACKER" => "true"}, "bin/rails runner 'puts Rails.env'") }
    end

    assert_equal "test", output.strip
  end

  def test_console_command_work_inside_engine
    skip "PTY unavailable" unless available_pty?

    primary, replica = PTY.open
    spawn_command("console", replica)
    assert_output(">", primary)
  ensure
    primary.puts "quit"
  end

  def test_dbconsole_command_work_inside_engine
    skip "PTY unavailable" unless available_pty?

    primary, replica = PTY.open
    spawn_command("dbconsole", replica)
    assert_output("sqlite>", primary)
  ensure
    primary.puts ".exit"
  end

  def test_server_command_work_inside_engine
    skip "PTY unavailable" unless available_pty?

    primary, replica = PTY.open
    pid = spawn_command("server", replica)
    assert_output("Listening on", primary)
  ensure
    kill(pid)
  end

  private
    def plugin_path
      "#{@destination_root}/bukkits"
    end

    def spawn_command(command, fd)
      Process.spawn(
        {"SKIP_REQUIRE_WEBPACKER" => "true"},
        "#{plugin_path}/bin/rails #{command}",
        in: fd, out: fd, err: fd
      )
    end

    def kill(pid)
      Process.kill("TERM", pid)
      Process.wait(pid)
    rescue Errno::ESRCH
    end
end
